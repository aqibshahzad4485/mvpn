#!/bin/bash

################################################################################
# WireGuard User Deletion Script
################################################################################

set -e

PROFILES_DIR="/etc/mvpn/profiles/wireguard"
CONFIG_DIR="/etc/mvpn/config"
LOG_FILE="/var/log/mvpn/user-management.log"
IP_DB="$CONFIG_DIR/wireguard-ips.db"
WG_CONFIG="/etc/wireguard/wg0.conf"

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

if [ ! -f "$PROFILES_DIR/$USERNAME.conf" ]; then
    echo "Error: User $USERNAME does not exist"
    exit 1
fi

# Get user's IP and public key
USER_IP=$(grep " $USERNAME " "$IP_DB" | awk '{print $1}')
USER_PUBLIC_KEY=$(grep "PrivateKey" "$PROFILES_DIR/$USERNAME.conf" | awk '{print $3}' | wg pubkey)

# Remove peer from server config
if [ -n "$USER_PUBLIC_KEY" ]; then
    # Remove the peer block
    sed -i "/PublicKey = $USER_PUBLIC_KEY/,+2d" $WG_CONFIG
fi

# Restart WireGuard
wg-quick down wg0 2>/dev/null || true
wg-quick up wg0

# Remove profiles
rm -f "$PROFILES_DIR/$USERNAME.conf"

# Mark IP as deleted
if [ -n "$USER_IP" ]; then
    sed -i "s/^$USER_IP $USERNAME ACTIVE/$USER_IP DELETED DELETED/" "$IP_DB"
    log "Marked IP $USER_IP as available for reuse"
fi

log "User $USERNAME deleted successfully"
echo "✓ User deleted: $USERNAME"
echo "  IP $USER_IP is now available for reuse"
