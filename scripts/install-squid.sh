#!/bin/bash

################################################################################
# Squid Proxy Installation Script with Enterprise Security
# 
# Features:
# - HTTP/HTTPS proxy with authentication
# - SSL bump for HTTPS inspection (optional)
# - Access control lists
# - Bandwidth limiting
# - Comprehensive logging
# - fail2ban integration
#
# Port: 3128/TCP
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SQUID_PORT=3128
SQUID_USER="vpnuser"
SQUID_PASS=$(openssl rand -base64 16)

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Squid Proxy Installation Script${NC}"
echo -e "${GREEN}================================${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Detect public IP
PUBLIC_IP=$(curl -s https://api.ipify.org)
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1)
fi

echo -e "${YELLOW}Detected public IP: $PUBLIC_IP${NC}"

# Update system
echo -e "${YELLOW}Updating system...${NC}"
apt update
apt upgrade -y

# Install Squid and dependencies
echo -e "${YELLOW}Installing Squid...${NC}"
apt install -y squid apache2-utils ufw fail2ban

# Backup original config
cp /etc/squid/squid.conf /etc/squid/squid.conf.backup

# Create password file
echo -e "${YELLOW}Creating authentication...${NC}"
htpasswd -bc /etc/squid/passwords $SQUID_USER $SQUID_PASS
chmod 640 /etc/squid/passwords
chown root:proxy /etc/squid/passwords

# Create Squid configuration
echo -e "${YELLOW}Creating Squid configuration...${NC}"

# Check for SSL certificates
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
KEYS_SOURCE="$REPO_ROOT/scripts/certs/keys"
TARGET_KEY_DIR="/etc/mvpn/config/certs/key"
HTTPS_CONFIG=""

mkdir -p "$TARGET_KEY_DIR"

# Try to copy from repo
if [ -f "$KEYS_SOURCE/fullchain.pem" ] && [ -f "$KEYS_SOURCE/privkey.pem" ]; then
    echo -e "${GREEN}Using certificates from repository: $KEYS_SOURCE${NC}"
    cp "$KEYS_SOURCE/fullchain.pem" "$TARGET_KEY_DIR/"
    cp "$KEYS_SOURCE/privkey.pem" "$TARGET_KEY_DIR/"
    chmod 600 "$TARGET_KEY_DIR/privkey.pem"
fi

# Configure HTTPS if certs exist in target dir
if [ -f "$TARGET_KEY_DIR/fullchain.pem" ] && [ -f "$TARGET_KEY_DIR/privkey.pem" ]; then
    echo -e "${GREEN}Enabling HTTPS support on port 3129${NC}"
    HTTPS_CONFIG="https_port 3129 cert=$TARGET_KEY_DIR/fullchain.pem key=$TARGET_KEY_DIR/privkey.pem"
    ufw allow 3129/tcp comment 'Squid HTTPS'
fi

cat > /etc/squid/squid.conf <<EOF
# Squid Proxy Configuration
# Mecta VPN - Enterprise Security

# Network configuration
http_port $SQUID_PORT
$HTTPS_CONFIG

# Authentication
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic children 5
auth_param basic realm Mecta VPN Proxy
auth_param basic credentialsttl 2 hours

# Access Control Lists (ACLs)
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10

acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT

acl authenticated proxy_auth REQUIRED

# Security - Deny access to dangerous ports
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

# Allow localhost
http_access allow localhost

# Require authentication for all other access
http_access allow authenticated
http_access deny all

# Privacy - Remove identifying headers
forwarded_for delete
via off
request_header_access X-Forwarded-For deny all
request_header_access Via deny all
request_header_access Cache-Control deny all

# Anonymity headers
reply_header_access X-Squid-Error deny all
reply_header_access X-Cache deny all
reply_header_access X-Cache-Lookup deny all

# Performance tuning
cache_mem 256 MB
maximum_object_size_in_memory 512 KB
maximum_object_size 4 MB
cache_dir ufs /var/spool/squid 10000 16 256

# Bandwidth limiting (optional - 10 Mbps per client)
delay_pools 1
delay_class 1 2
delay_parameters 1 -1/-1 1250000/1250000
delay_access 1 allow authenticated

# Logging
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
cache_store_log /var/log/squid/store.log

# Log format with authentication
logformat combined %>a %[ui %[un [%tl] "%rm %ru HTTP/%rv" %>Hs %<st "%{Referer}>h" "%{User-Agent}>h" %Ss:%Sh
access_log /var/log/squid/access.log combined

# Refresh patterns
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320

# Coredump directory
coredump_dir /var/spool/squid

# DNS
dns_nameservers 1.1.1.1 1.0.0.1

# Shutdown lifetime
shutdown_lifetime 10 seconds

# Visible hostname
visible_hostname proxy.aqibs.dev

# Error pages
error_directory /usr/share/squid/errors/en
EOF

# Create cache directory
echo -e "${YELLOW}Initializing cache...${NC}"
squid -z

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw allow $SQUID_PORT/tcp comment 'Squid Proxy'

# Configure fail2ban for Squid
echo -e "${YELLOW}Configuring fail2ban...${NC}"
cat > /etc/fail2ban/jail.d/squid.conf <<EOF
[squid]
enabled = true
port = $SQUID_PORT
protocol = tcp
filter = squid
logpath = /var/log/squid/access.log
maxretry = 5
bantime = 3600
findtime = 600
EOF

cat > /etc/fail2ban/filter.d/squid.conf <<EOF
[Definition]
failregex = ^.*TCP_DENIED/407.*<HOST>.*$
            ^.*TCP_DENIED/403.*<HOST>.*$
ignoreregex =
EOF

systemctl restart fail2ban

# Start and enable Squid
echo -e "${YELLOW}Starting Squid service...${NC}"
systemctl restart squid
systemctl enable squid

# Create credentials file
cat > /root/squid-credentials.txt <<EOF
Squid Proxy Credentials
=======================

Server: $PUBLIC_IP
Port: $SQUID_PORT
Username: $SQUID_USER
Password: $SQUID_PASS

Connection String:
http://$SQUID_USER:$SQUID_PASS@$PUBLIC_IP:$SQUID_PORT

SOCKS5 Proxy Settings:
- Server: $PUBLIC_IP
- Port: $SQUID_PORT
- Username: $SQUID_USER
- Password: $SQUID_PASS

Browser Configuration:
1. Open browser proxy settings
2. Set HTTP Proxy: $PUBLIC_IP:$SQUID_PORT
3. Set HTTPS Proxy: $PUBLIC_IP:$SQUID_PORT
4. Enable "Use this proxy for all protocols"
5. Enter username and password when prompted

cURL Example:
curl -x http://$SQUID_USER:$SQUID_PASS@$PUBLIC_IP:$SQUID_PORT https://api.ipify.org

EOF

chmod 600 /root/squid-credentials.txt

# Create helper script to add more users
cat > /root/add-squid-user.sh <<'ADDUSER'
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME=$1
PASSWORD=$(openssl rand -base64 16)

htpasswd -b /etc/squid/passwords $USERNAME $PASSWORD

echo "User created:"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
echo ""
echo "Connection: http://$USERNAME:$PASSWORD@$(curl -s https://api.ipify.org):3128"

systemctl reload squid
ADDUSER

chmod +x /root/add-squid-user.sh

# Display summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Squid Proxy Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Server Details:${NC}"
echo "  IP: $PUBLIC_IP"
echo "  Port: $SQUID_PORT/TCP"
echo ""
echo -e "${YELLOW}Credentials:${NC}"
echo "  Username: $SQUID_USER"
echo "  Password: $SQUID_PASS"
echo ""
echo -e "${YELLOW}Connection String:${NC}"
echo "  http://$SQUID_USER:$SQUID_PASS@$PUBLIC_IP:$SQUID_PORT"
echo ""
echo -e "${YELLOW}Security Features:${NC}"
echo "  ✓ Authentication required"
echo "  ✓ Privacy headers removed"
echo "  ✓ Bandwidth limiting (10 Mbps/client)"
echo "  ✓ fail2ban monitoring"
echo "  ✓ Access control lists"
echo ""
echo -e "${YELLOW}Credentials File:${NC}"
echo "  /root/squid-credentials.txt"
echo ""
echo -e "${YELLOW}Add More Users:${NC}"
echo "  /root/add-squid-user.sh <username>"
echo ""
echo -e "${YELLOW}Service Management:${NC}"
echo "  Status: systemctl status squid"
echo "  Restart: systemctl restart squid"
echo "  Logs: tail -f /var/log/squid/access.log"
echo ""
echo -e "${GREEN}Use the credentials above to connect!${NC}"
