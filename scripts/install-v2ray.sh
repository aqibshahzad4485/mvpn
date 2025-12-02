#!/bin/bash

################################################################################
# V2Ray/Xray Installation Script with Enterprise Security
# 
# Features:
# - VMess and VLESS protocols
# - TLS 1.3 with Let's Encrypt
# - WebSocket transport
# - CDN-friendly
# - Traffic obfuscation
# - Comprehensive logging
#
# IP Range: 10.10.0.0/16
# Port: 443/TCP (HTTPS)
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
XRAY_PORT=443
DOMAIN=""
EMAIL="admin@aqibs.dev"

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}V2Ray/Xray Installation Script${NC}"
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

# Ask for domain if not provided
if [ -z "$DOMAIN" ]; then
    echo -e "${YELLOW}Enter your domain name (must point to $PUBLIC_IP):${NC}"
    read -p "Domain: " DOMAIN
fi

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain is required for TLS!${NC}"
    exit 1
fi

# Verify DNS
echo -e "${YELLOW}Verifying DNS...${NC}"
RESOLVED_IP=$(dig +short $DOMAIN | tail -1)
if [ "$RESOLVED_IP" != "$PUBLIC_IP" ]; then
    echo -e "${RED}Warning: Domain $DOMAIN resolves to $RESOLVED_IP, not $PUBLIC_IP${NC}"
    echo -e "${YELLOW}Please update your DNS records and try again.${NC}"
    if [ -z "$NON_INTERACTIVE" ]; then
        read -p "Continue anyway? (y/N): " CONTINUE
        if [ "$CONTINUE" != "y" ]; then
            exit 1
        fi
    else
        echo -e "${YELLOW}Running in non-interactive mode, proceeding anyway...${NC}"
    fi
fi

# Update system
echo -e "${YELLOW}Updating system...${NC}"
apt update
apt upgrade -y

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
apt install -y curl wget unzip nginx certbot python3-certbot-nginx ufw fail2ban jq

# Open HTTP port for Certbot
echo -e "${YELLOW}Opening port 80 for SSL verification...${NC}"
ufw allow 80/tcp comment 'HTTP'

# Install Xray
echo -e "${YELLOW}Installing Xray...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Generate UUID for VMess
UUID=$(cat /proc/sys/kernel/random/uuid)

# Generate random path
WS_PATH="/$(openssl rand -hex 8)"

# SSL Certificate Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
KEYS_SOURCE="$REPO_ROOT/scripts/certs/keys"
TARGET_KEY_DIR="/etc/mvpn/config/certs/key"

mkdir -p "$TARGET_KEY_DIR"

if [ -f "$KEYS_SOURCE/fullchain.pem" ] && [ -f "$KEYS_SOURCE/privkey.pem" ]; then
    echo -e "${GREEN}Using certificates from repository: $KEYS_SOURCE${NC}"
    cp "$KEYS_SOURCE/fullchain.pem" "$TARGET_KEY_DIR/"
    cp "$KEYS_SOURCE/privkey.pem" "$TARGET_KEY_DIR/"
    chmod 600 "$TARGET_KEY_DIR/privkey.pem"
    
    # Link to Let's Encrypt path for compatibility if needed, but we use direct path now
    mkdir -p "/etc/letsencrypt/live/$DOMAIN"
    ln -sf "$TARGET_KEY_DIR/fullchain.pem" "/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    ln -sf "$TARGET_KEY_DIR/privkey.pem" "/etc/letsencrypt/live/$DOMAIN/privkey.pem"
else
    # Fallback to Certbot (only if keys not in repo)
    echo -e "${YELLOW}Certificates not found in repo keys. Trying Certbot...${NC}"
    systemctl stop nginx 2>/dev/null || true
    certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --preferred-challenges http
    
    # Copy generated certs to target dir for consistency
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$TARGET_KEY_DIR/"
        cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$TARGET_KEY_DIR/"
    fi
fi

# Configure Nginx as reverse proxy
echo -e "${YELLOW}Configuring Nginx...${NC}"
cat > /etc/nginx/sites-available/xray <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # Use certificates from config dir
    ssl_certificate $TARGET_KEY_DIR/fullchain.pem;
    ssl_certificate_key $TARGET_KEY_DIR/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        root /var/www/html;
        index index.html;
    }

    location $WS_PATH {
        if (\$http_upgrade != "websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

ln -sf /etc/nginx/sites-available/xray /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Create simple landing page
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>Welcome to $DOMAIN</h1>
    <p>This site is running on Nginx.</p>
</body>
</html>
EOF

systemctl restart nginx
systemctl enable nginx

# Create Xray configuration
echo -e "${YELLOW}Creating Xray configuration...${NC}"
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": 10000,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$WS_PATH"
        }
      }
    },
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${WS_PATH}-vless"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF

# Create log directory
mkdir -p /var/log/xray
chmod 755 /var/log/xray

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS/Xray'

# Configure fail2ban for Nginx
echo -e "${YELLOW}Configuring fail2ban...${NC}"
cat > /etc/fail2ban/jail.d/nginx.conf <<EOF
[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 3600
findtime = 600

[nginx-noscript]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 6
bantime = 3600
findtime = 600
EOF

systemctl restart fail2ban

# Start and enable Xray
echo -e "${YELLOW}Starting Xray service...${NC}"
systemctl restart xray
systemctl enable xray

# Generate client configurations
echo -e "${YELLOW}Generating client configurations...${NC}"

# VMess link
VMESS_JSON=$(cat <<VMESSJSON
{
  "v": "2",
  "ps": "Mecta VPN - $DOMAIN",
  "add": "$DOMAIN",
  "port": "$XRAY_PORT",
  "id": "$UUID",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "$DOMAIN",
  "path": "$WS_PATH",
  "tls": "tls"
}
VMESSJSON
)

VMESS_LINK="vmess://$(echo -n $VMESS_JSON | base64 -w 0)"

# VLESS link
VLESS_LINK="vless://$UUID@$DOMAIN:$XRAY_PORT?encryption=none&security=tls&type=ws&host=$DOMAIN&path=${WS_PATH}-vless#Mecta%20VPN%20-%20$DOMAIN"

# Save links
cat > /root/v2ray-links.txt <<EOF
V2Ray/Xray Client Configuration
================================

Domain: $DOMAIN
UUID: $UUID

VMess Configuration:
-------------------
$VMESS_LINK

VLESS Configuration:
-------------------
$VLESS_LINK

Manual Configuration (VMess):
-----------------------------
Address: $DOMAIN
Port: $XRAY_PORT
UUID: $UUID
AlterID: 0
Security: auto
Network: ws
Path: $WS_PATH
TLS: enabled
Host: $DOMAIN

Manual Configuration (VLESS):
-----------------------------
Address: $DOMAIN
Port: $XRAY_PORT
UUID: $UUID
Encryption: none
Network: ws
Path: ${WS_PATH}-vless
TLS: enabled
Host: $DOMAIN

Supported Clients:
- V2RayN (Windows)
- V2RayNG (Android)
- Shadowrocket (iOS)
- Qv2ray (Linux/macOS/Windows)
- V2RayX (macOS)

Import: Copy the VMess or VLESS link above and import into your client.
EOF

chmod 600 /root/v2ray-links.txt

# Create helper script to add more users
cat > /root/add-v2ray-user.sh <<'ADDUSER'
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME=$1
NEW_UUID=$(cat /proc/sys/kernel/random/uuid)
DOMAIN=$(grep "server_name" /etc/nginx/sites-available/xray | head -1 | awk '{print $2}' | tr -d ';')
WS_PATH=$(grep "location" /etc/nginx/sites-available/xray | grep -v "/" | awk '{print $2}')

# Add to Xray config (VMess)
jq ".inbounds[0].settings.clients += [{\"id\": \"$NEW_UUID\", \"alterId\": 0}]" /usr/local/etc/xray/config.json > /tmp/config.json
mv /tmp/config.json /usr/local/etc/xray/config.json

# Add to Xray config (VLESS)
jq ".inbounds[1].settings.clients += [{\"id\": \"$NEW_UUID\"}]" /usr/local/etc/xray/config.json > /tmp/config.json
mv /tmp/config.json /usr/local/etc/xray/config.json

systemctl restart xray

# Generate links
VMESS_JSON="{\"v\":\"2\",\"ps\":\"$USERNAME\",\"add\":\"$DOMAIN\",\"port\":\"443\",\"id\":\"$NEW_UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$DOMAIN\",\"path\":\"$WS_PATH\",\"tls\":\"tls\"}"
VMESS_LINK="vmess://$(echo -n $VMESS_JSON | base64 -w 0)"
VLESS_LINK="vless://$NEW_UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=${WS_PATH}-vless#$USERNAME"

cat > /root/${USERNAME}-v2ray.txt <<EOF
User: $USERNAME
UUID: $NEW_UUID

VMess: $VMESS_LINK
VLESS: $VLESS_LINK
EOF

echo "User $USERNAME created!"
echo "Config: /root/${USERNAME}-v2ray.txt"
ADDUSER

chmod +x /root/add-v2ray-user.sh

# Setup auto-renewal for SSL
echo -e "${YELLOW}Setting up SSL auto-renewal...${NC}"
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -

# Display summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}V2Ray/Xray Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Server Details:${NC}"
echo "  Domain: $DOMAIN"
echo "  Port: $XRAY_PORT/TCP (HTTPS)"
echo "  UUID: $UUID"
echo ""
echo -e "${YELLOW}Security Features:${NC}"
echo "  ✓ TLS 1.3 encryption"
echo "  ✓ WebSocket transport"
echo "  ✓ CDN-compatible"
echo "  ✓ Traffic obfuscation"
echo "  ✓ fail2ban monitoring"
echo ""
echo -e "${YELLOW}Protocols:${NC}"
echo "  ✓ VMess (path: $WS_PATH)"
echo "  ✓ VLESS (path: ${WS_PATH}-vless)"
echo ""
echo -e "${YELLOW}Client Links:${NC}"
echo "  File: /root/v2ray-links.txt"
echo ""
echo -e "${YELLOW}Add More Users:${NC}"
echo "  /root/add-v2ray-user.sh <username>"
echo ""
echo -e "${YELLOW}Service Management:${NC}"
echo "  Xray: systemctl status xray"
echo "  Nginx: systemctl status nginx"
echo "  Logs: tail -f /var/log/xray/access.log"
echo ""
echo -e "${GREEN}Import the VMess/VLESS link to connect!${NC}"
