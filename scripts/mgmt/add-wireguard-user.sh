#!/bin/bash

################################################################################
# WireGuard User Management Script
# 
# Usage:
#   ./add-wireguard-user.sh <username>
#
# Features:
# - Intelligent IP allocation (reuses deleted user IPs)
# - Generates keys and QR code
# - Non-interactive
################################################################################

set -e

# Directories
PROFILES_DIR="/etc/mvpn/profiles/wireguard"
CONFIG_DIR="/etc/mvpn/config"
LOG_FILE="/var/log/mvpn/user-management.log"
IP_DB="$CONFIG_DIR/wireguard-ips.db"
WG_CONFIG="/etc/wireguard/wg0.conf"

# IP Range for WireGuard: 10.9.0.0/16
NETWORK_PREFIX="10.9"
MIN_IP=2
MAX_IP=65534

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME=$1

# Validate username
if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Username must contain only letters, numbers, dash, or underscore"
    exit 1
fi

# Check if user exists
if [ -f "$PROFILES_DIR/$USERNAME.conf" ]; then
    echo "Error: User $USERNAME already exists"
    exit 1
fi

# Create directories
mkdir -p "$PROFILES_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Initialize IP database
if [ ! -f "$IP_DB" ]; then
    echo "# WireGuard IP Allocation Database" > "$IP_DB"
    echo "# Format: IP_ADDRESS USERNAME STATUS" >> "$IP_DB"
fi

# Find available IP
find_available_ip() {
    REUSED_IP=$(grep "DELETED" "$IP_DB" | head -1 | awk '{print $1}')
    
    if [ -n "$REUSED_IP" ]; then
        echo "$REUSED_IP"
        return
    fi
    
    LAST_OCTET=$(grep -v "^#" "$IP_DB" | grep -v "DELETED" | awk '{print $1}' | cut -d'.' -f4 | sort -n | tail -1)
    
    if [ -z "$LAST_OCTET" ]; then
        echo "${NETWORK_PREFIX}.0.${MIN_IP}"
        return
    fi
    
    NEXT_OCTET=$((LAST_OCTET + 1))
    
    if [ $NEXT_OCTET -gt 255 ]; then
        LAST_SUBNET=$(grep -v "^#" "$IP_DB" | grep -v "DELETED" | awk '{print $1}' | cut -d'.' -f3 | sort -n | tail -1)
        NEXT_SUBNET=$((LAST_SUBNET + 1))
        
        if [ $NEXT_SUBNET -gt 255 ]; then
            echo "Error: IP pool exhausted!"
            exit 1
        fi
        
        echo "${NETWORK_PREFIX}.${NEXT_SUBNET}.1"
    else
        CURRENT_SUBNET=$(grep -v "^#" "$IP_DB" | grep -v "DELETED" | awk '{print $1}' | cut -d'.' -f3 | tail -1)
        [ -z "$CURRENT_SUBNET" ] && CURRENT_SUBNET=0
        echo "${NETWORK_PREFIX}.${CURRENT_SUBNET}.${NEXT_OCTET}"
    fi
}

# Allocate IP
CLIENT_IP=$(find_available_ip)
log "Allocating IP $CLIENT_IP to user $USERNAME"

# Generate keys
cd /etc/wireguard
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
PRESHARED_KEY=$(wg genpsk)

# Get server info
SERVER_PUBLIC_KEY=$(grep "PrivateKey" $WG_CONFIG | awk '{print $3}' | wg pubkey)
PUBLIC_IP=$(curl -s https://api.ipify.org)
WG_PORT=$(grep "ListenPort" $WG_CONFIG | awk '{print $3}')

# Add peer to server config
cat >> $WG_CONFIG <<EOF

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $PRESHARED_KEY
AllowedIPs = $CLIENT_IP/32
EOF

# Restart WireGuard
wg-quick down wg0 2>/dev/null || true
wg-quick up wg0

# Generate client config
cat > "$PROFILES_DIR/$USERNAME.conf" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/16
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $PRESHARED_KEY
Endpoint = $PUBLIC_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

chmod 600 "$PROFILES_DIR/$USERNAME.conf"

# Generate QR code
if command -v qrencode &> /dev/null; then
    qrencode -t ansiutf8 < "$PROFILES_DIR/$USERNAME.conf" > "$PROFILES_DIR/$USERNAME-qr.txt"
    qrencode -t png -o "$PROFILES_DIR/$USERNAME-qr.png" < "$PROFILES_DIR/$USERNAME.conf"
fi

# Update IP database
if grep -q "$CLIENT_IP" "$IP_DB" && grep "$CLIENT_IP" "$IP_DB" | grep -q "DELETED"; then
    sed -i "s/^$CLIENT_IP.*/$CLIENT_IP $USERNAME ACTIVE/" "$IP_DB"
    log "Reused IP $CLIENT_IP"
else
    echo "$CLIENT_IP $USERNAME ACTIVE" >> "$IP_DB"
    log "Allocated new IP $CLIENT_IP"
fi

# Success
log "User $USERNAME created successfully"
echo "✓ User created: $USERNAME"
echo "  IP: $CLIENT_IP"
echo "  Profile: $PROFILES_DIR/$USERNAME.conf"
[ -f "$PROFILES_DIR/$USERNAME-qr.png" ] && echo "  QR Code: $PROFILES_DIR/$USERNAME-qr.png"
