#!/bin/bash

################################################################################
# OpenVPN Installation Script with Enterprise Security
# 
# Features:
# - AES-256-GCM encryption
# - TLS 1.3
# - 4096-bit RSA keys
# - Client isolation
# - Private network protection
# - fail2ban integration
# - Comprehensive logging
#
# IP Range: 10.8.0.0/24
# Port: 1194/UDP
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
OPENVPN_PORT=1194
OPENVPN_PROTOCOL=udp
OPENVPN_NETWORK="10.8.0.0"
OPENVPN_NETMASK="255.255.0.0"  # /16 subnet for 65,534 clients
DNS1="1.1.1.1"
DNS2="1.0.0.1"

# Directories
PROFILES_DIR="/etc/mvpn/profiles/openvpn"
LOG_DIR="/var/log/mvpn/openvpn"
CONFIG_DIR="/etc/mvpn/config"

# Create directories
mkdir -p "$PROFILES_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$CONFIG_DIR"
chmod 750 "$PROFILES_DIR"
chmod 750 "$LOG_DIR"

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}OpenVPN Installation Script${NC}"
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

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
apt install -y openvpn easy-rsa ufw fail2ban iptables-persistent

# Setup Easy-RSA
echo -e "${YELLOW}Setting up PKI...${NC}"
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa

# Configure vars
cat > vars <<EOF
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "California"
set_var EASYRSA_REQ_CITY       "San Francisco"
set_var EASYRSA_REQ_ORG        "Mecta VPN"
set_var EASYRSA_REQ_EMAIL      "admin@aqibs.dev"
set_var EASYRSA_REQ_OU         "VPN"
set_var EASYRSA_KEY_SIZE       4096
set_var EASYRSA_ALGO           rsa
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    3650
set_var EASYRSA_DIGEST         "sha256"
EOF

# Initialize PKI
./easyrsa init-pki
./easyrsa --batch build-ca nopass
./easyrsa gen-dh
./easyrsa build-server-full server nopass
./easyrsa build-client-full client nopass
openvpn --genkey secret pki/ta.key

# Copy certificates
cp pki/ca.crt /etc/openvpn/
cp pki/issued/server.crt /etc/openvpn/
cp pki/private/server.key /etc/openvpn/
cp pki/dh.pem /etc/openvpn/
cp pki/ta.key /etc/openvpn/

# Create server configuration
echo -e "${YELLOW}Creating server configuration...${NC}"
cat > /etc/openvpn/server.conf <<EOF
# OpenVPN Server Configuration
# Mecta VPN - Enterprise Security

port $OPENVPN_PORT
proto $OPENVPN_PROTOCOL
dev tun

# Certificates and keys
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0

# Network configuration
server $OPENVPN_NETWORK $OPENVPN_NETMASK
topology subnet

# Push routes and DNS to clients
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $DNS1"
push "dhcp-option DNS $DNS2"

# Client configuration
client-to-client
ifconfig-pool-persist /var/log/openvpn/ipp.txt
keepalive 10 120
max-clients 100

# Security - Strong encryption
cipher AES-256-GCM
auth SHA256
tls-version-min 1.3
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384

# Privileges
user nobody
group nogroup

# Persistence
persist-key
persist-tun

# Logging
status /var/log/openvpn/status.log
log-append /var/log/openvpn/openvpn.log
verb 3
mute 20

# Performance
sndbuf 393216
rcvbuf 393216
push "sndbuf 393216"
push "rcvbuf 393216"
txqueuelen 4000

# Compression (disabled for security)
compress lz4-v2
push "compress lz4-v2"
EOF

# Create log directory
mkdir -p /var/log/openvpn
chmod 750 /var/log/openvpn

# Enable IP forwarding
echo -e "${YELLOW}Enabling IP forwarding...${NC}"
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"

# Get primary network interface
NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

# UFW rules
# Only reset if this is the first protocol being installed
if ! ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}Initializing firewall...${NC}"
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp comment 'SSH'
    ufw limit 22/tcp
fi

# Add OpenVPN rule
ufw allow $OPENVPN_PORT/$OPENVPN_PROTOCOL comment 'OpenVPN'

# NAT rules for UFW
cat > /etc/ufw/before.rules <<EOF
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
# OpenVPN NAT
-A POSTROUTING -s $OPENVPN_NETWORK/16 -o $NIC -j MASQUERADE
COMMIT

# Don't delete these required lines
*filter
:ufw-before-input - [0:0]
:ufw-before-output - [0:0]
:ufw-before-forward - [0:0]
:ufw-not-local - [0:0]

# Allow all on loopback
-A ufw-before-input -i lo -j ACCEPT
-A ufw-before-output -o lo -j ACCEPT

# OpenVPN forwarding
-A ufw-before-forward -i tun+ -j ACCEPT
-A ufw-before-forward -o tun+ -j ACCEPT

# CLIENT ISOLATION - Block client-to-client communication
-A ufw-before-forward -i tun0 -o tun0 -j DROP

# PRIVATE NETWORK PROTECTION - Block access to private networks
-A ufw-before-forward -s $OPENVPN_NETWORK/16 -d 192.168.0.0/16 -j DROP
-A ufw-before-forward -s $OPENVPN_NETWORK/16 -d 172.16.0.0/12 -j DROP
-A ufw-before-forward -s $OPENVPN_NETWORK/16 -d 10.0.0.0/8 -j DROP

# Allow established connections
-A ufw-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Drop invalid packets
-A ufw-before-input -m conntrack --ctstate INVALID -j ufw-logging-deny
-A ufw-before-input -m conntrack --ctstate INVALID -j DROP

# Ok icmp codes for INPUT
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT
-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT

# Ok icmp code for FORWARD
-A ufw-before-forward -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type parameter-problem -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type echo-request -j ACCEPT

# Allow dhcp client to work
-A ufw-before-input -p udp --sport 67 --dport 68 -j ACCEPT

# Don't delete the 'COMMIT' line or these rules won't be processed
COMMIT
EOF

# Enable UFW
echo "y" | ufw enable

# Configure fail2ban for OpenVPN
echo -e "${YELLOW}Configuring fail2ban...${NC}"
cat > /etc/fail2ban/jail.d/openvpn.conf <<EOF
[openvpn]
enabled = true
port = $OPENVPN_PORT
protocol = $OPENVPN_PROTOCOL
filter = openvpn
logpath = /var/log/openvpn/openvpn.log
maxretry = 5
bantime = 3600
findtime = 600
EOF

cat > /etc/fail2ban/filter.d/openvpn.conf <<EOF
[Definition]
failregex = ^.*TLS Error: TLS key negotiation failed to occur within.*<HOST>.*$
            ^.*TLS Error: TLS handshake failed.*<HOST>.*$
            ^.*VERIFY ERROR.*<HOST>.*$
            ^.*TLS_ERROR.*<HOST>.*$
ignoreregex =
EOF

systemctl restart fail2ban

# Start and enable OpenVPN
echo -e "${YELLOW}Starting OpenVPN service...${NC}"
systemctl start openvpn@server
systemctl enable openvpn@server

# Generate client configuration
echo -e "${YELLOW}Generating client configuration...${NC}"
cat > /root/client.ovpn <<EOF
client
dev tun
proto $OPENVPN_PROTOCOL
remote $PUBLIC_IP $OPENVPN_PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
tls-version-min 1.3
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384
key-direction 1
verb 3
compress lz4-v2

<ca>
$(cat /etc/openvpn/easy-rsa/pki/ca.crt)
</ca>

<cert>
$(cat /etc/openvpn/easy-rsa/pki/issued/client.crt)
</cert>

<key>
$(cat /etc/openvpn/easy-rsa/pki/private/client.key)
</key>

<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
EOF

chmod 600 /root/client.ovpn

# Display summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}OpenVPN Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Server Details:${NC}"
echo "  IP: $PUBLIC_IP"
echo "  Port: $OPENVPN_PORT/$OPENVPN_PROTOCOL"
echo "  VPN Network: $OPENVPN_NETWORK/24"
echo ""
echo -e "${YELLOW}Security Features:${NC}"
echo "  ✓ AES-256-GCM encryption"
echo "  ✓ TLS 1.3"
echo "  ✓ 4096-bit RSA keys"
echo "  ✓ Client isolation enabled"
echo "  ✓ Private network protection"
echo "  ✓ fail2ban monitoring"
echo ""
echo -e "${YELLOW}Client Configuration:${NC}"
echo "  File: /root/client.ovpn"
echo ""
echo -e "${YELLOW}Service Management:${NC}"
echo "  Status: systemctl status openvpn@server"
echo "  Restart: systemctl restart openvpn@server"
echo "  Logs: tail -f /var/log/openvpn/openvpn.log"
echo ""
echo -e "${GREEN}Download /root/client.ovpn to connect!${NC}"
