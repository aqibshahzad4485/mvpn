#!/bin/bash

################################################################################
# V2Ray User Management Script
################################################################################

set -e

PROFILES_DIR="/etc/mvpn/profiles/v2ray"
CONFIG_DIR="/etc/mvpn/config"
LOG_FILE="/var/log/mvpn/user-management.log"
XRAY_CONFIG="/usr/local/etc/xray/config.json"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME=$1

if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Username must contain only letters, numbers, dash, or underscore"
    exit 1
fi

if [ -f "$PROFILES_DIR/$USERNAME.txt" ]; then
    echo "Error: User $USERNAME already exists"
    exit 1
fi

mkdir -p "$PROFILES_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Generate UUID
NEW_UUID=$(cat /proc/sys/kernel/random/uuid)

# Get server info
DOMAIN=$(grep "server_name" /etc/nginx/sites-available/xray 2>/dev/null | head -1 | awk '{print $2}' | tr -d ';')
WS_PATH=$(grep "location" /etc/nginx/sites-available/xray 2>/dev/null | grep -v "/" | head -1 | awk '{print $2}')

if [ -z "$DOMAIN" ] || [ -z "$WS_PATH" ]; then
    echo "Error: V2Ray configuration not found"
    exit 1
fi

# Add to Xray config (VMess)
jq ".inbounds[0].settings.clients += [{\"id\": \"$NEW_UUID\", \"alterId\": 0}]" $XRAY_CONFIG > /tmp/config.json
mv /tmp/config.json $XRAY_CONFIG

# Add to Xray config (VLESS)
jq ".inbounds[1].settings.clients += [{\"id\": \"$NEW_UUID\"}]" $XRAY_CONFIG > /tmp/config.json
mv /tmp/config.json $XRAY_CONFIG

# Restart Xray
systemctl restart xray

# Generate links
VMESS_JSON="{\"v\":\"2\",\"ps\":\"$USERNAME\",\"add\":\"$DOMAIN\",\"port\":\"443\",\"id\":\"$NEW_UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$DOMAIN\",\"path\":\"$WS_PATH\",\"tls\":\"tls\"}"
VMESS_LINK="vmess://$(echo -n $VMESS_JSON | base64 -w 0)"
VLESS_LINK="vless://$NEW_UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=${WS_PATH}-vless#$USERNAME"

# Save to file
cat > "$PROFILES_DIR/$USERNAME.txt" <<EOF
V2Ray/Xray Configuration
========================

User: $USERNAME
UUID: $NEW_UUID
Domain: $DOMAIN

VMess Link:
$VMESS_LINK

VLESS Link:
$VLESS_LINK

Manual Configuration (VMess):
- Address: $DOMAIN
- Port: 443
- UUID: $NEW_UUID
- AlterID: 0
- Network: ws
- Path: $WS_PATH
- TLS: enabled

Manual Configuration (VLESS):
- Address: $DOMAIN
- Port: 443
- UUID: $NEW_UUID
- Network: ws
- Path: ${WS_PATH}-vless
- TLS: enabled
EOF

chmod 600 "$PROFILES_DIR/$USERNAME.txt"

log "User $USERNAME created successfully"
echo "✓ User created: $USERNAME"
echo "  UUID: $NEW_UUID"
echo "  Profile: $PROFILES_DIR/$USERNAME.txt"
echo ""
echo "VMess: $VMESS_LINK"
echo ""
echo "VLESS: $VLESS_LINK"
