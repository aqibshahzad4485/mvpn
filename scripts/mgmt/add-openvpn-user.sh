#!/bin/bash

################################################################################
# OpenVPN User Management Script
# 
# Usage:
#   ./add-openvpn-user.sh <username>
#   ./add-openvpn-user.sh john
#
# Features:
# - Intelligent IP allocation (reuses deleted user IPs)
# - Tracks used IPs in /etc/mvpn/config/openvpn-ips.db
# - Generates .ovpn profile
# - Non-interactive
################################################################################

set -e

# Directories
PROFILES_DIR="/etc/mvpn/profiles/openvpn"
CONFIG_DIR="/etc/mvpn/config"
LOG_FILE="/var/log/mvpn/user-management.log"
IP_DB="$CONFIG_DIR/openvpn-ips.db"
EASYRSA_DIR="/etc/openvpn/easy-rsa"

# IP Range for OpenVPN: 10.8.0.0/16
NETWORK_PREFIX="10.8"
MIN_IP=2
MAX_IP=65534

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if running as root
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

# Validate username (alphanumeric, dash, underscore only)
if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Username must contain only letters, numbers, dash, or underscore"
    exit 1
fi

# Check if user already exists
if [ -f "$PROFILES_DIR/$USERNAME.ovpn" ]; then
    echo "Error: User $USERNAME already exists"
    exit 1
fi

# Create directories if they don't exist
mkdir -p "$PROFILES_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Initialize IP database if it doesn't exist
if [ ! -f "$IP_DB" ]; then
    echo "# OpenVPN IP Allocation Database" > "$IP_DB"
    echo "# Format: IP_ADDRESS USERNAME STATUS" >> "$IP_DB"
fi

# Function to find next available IP
find_available_ip() {
    # First, try to find a deleted user's IP
    REUSED_IP=$(grep "DELETED" "$IP_DB" | head -1 | awk '{print $1}')
    
    if [ -n "$REUSED_IP" ]; then
        echo "$REUSED_IP"
        return
    fi
    
    # Find highest used IP
    LAST_OCTET=$(grep -v "^#" "$IP_DB" | grep -v "DELETED" | awk '{print $1}' | cut -d'.' -f4 | sort -n | tail -1)
    
    if [ -z "$LAST_OCTET" ]; then
        # No IPs allocated yet, start from MIN_IP
        echo "${NETWORK_PREFIX}.0.${MIN_IP}"
        return
    fi
    
    # Calculate next IP
    NEXT_OCTET=$((LAST_OCTET + 1))
    
    # Check if we need to move to next subnet
    if [ $NEXT_OCTET -gt 255 ]; then
        # Find next available subnet
        LAST_SUBNET=$(grep -v "^#" "$IP_DB" | grep -v "DELETED" | awk '{print $1}' | cut -d'.' -f3 | sort -n | tail -1)
        NEXT_SUBNET=$((LAST_SUBNET + 1))
        
        if [ $NEXT_SUBNET -gt 255 ]; then
            echo "Error: IP pool exhausted!"
            exit 1
        fi
        
        echo "${NETWORK_PREFIX}.${NEXT_SUBNET}.1"
    else
        CURRENT_SUBNET=$(grep -v "^#" "$IP_DB" | grep -v "DELETED" | awk '{print $1}' | cut -d'.' -f3 | tail -1)
        echo "${NETWORK_PREFIX}.${CURRENT_SUBNET}.${NEXT_OCTET}"
    fi
}

# Allocate IP
CLIENT_IP=$(find_available_ip)
log "Allocating IP $CLIENT_IP to user $USERNAME"

# Generate certificate
log "Generating certificate for $USERNAME..."
cd "$EASYRSA_DIR"
./easyrsa --batch build-client-full "$USERNAME" nopass

# Get server info
PUBLIC_IP=$(curl -s https://api.ipify.org)
OPENVPN_PORT=$(grep "^port" /etc/openvpn/server.conf | awk '{print $2}')
OPENVPN_PROTO=$(grep "^proto" /etc/openvpn/server.conf | awk '{print $2}')

# Generate client configuration
log "Generating client configuration..."
cat > "$PROFILES_DIR/$USERNAME.ovpn" <<EOF
client
dev tun
proto $OPENVPN_PROTO
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
$(cat "$EASYRSA_DIR/pki/ca.crt")
</ca>

<cert>
$(cat "$EASYRSA_DIR/pki/issued/$USERNAME.crt")
</cert>

<key>
$(cat "$EASYRSA_DIR/pki/private/$USERNAME.key")
</key>

<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
EOF

chmod 600 "$PROFILES_DIR/$USERNAME.ovpn"

# Update IP database
if grep -q "$CLIENT_IP" "$IP_DB" && grep "$CLIENT_IP" "$IP_DB" | grep -q "DELETED"; then
    # Reusing deleted IP
    sed -i "s/^$CLIENT_IP.*/$CLIENT_IP $USERNAME ACTIVE/" "$IP_DB"
    log "Reused IP $CLIENT_IP (previously deleted)"
else
    # New IP allocation
    echo "$CLIENT_IP $USERNAME ACTIVE" >> "$IP_DB"
    log "Allocated new IP $CLIENT_IP"
fi

# Success
log "User $USERNAME created successfully"
echo "✓ User created: $USERNAME"
echo "  IP: $CLIENT_IP"
echo "  Profile: $PROFILES_DIR/$USERNAME.ovpn"
echo ""
echo "Download the profile and import into OpenVPN client."
