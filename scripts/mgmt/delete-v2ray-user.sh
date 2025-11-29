#!/bin/bash

################################################################################
# V2Ray User Deletion Script
################################################################################

set -e

PROFILES_DIR="/etc/mvpn/profiles/v2ray"
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

if [ ! -f "$PROFILES_DIR/$USERNAME.txt" ]; then
    echo "Error: User $USERNAME does not exist"
    exit 1
fi

# Get UUID
USER_UUID=$(grep "UUID:" "$PROFILES_DIR/$USERNAME.txt" | awk '{print $2}')

if [ -n "$USER_UUID" ]; then
    # Remove from VMess
    jq "del(.inbounds[0].settings.clients[] | select(.id == \"$USER_UUID\"))" $XRAY_CONFIG > /tmp/config.json
    mv /tmp/config.json $XRAY_CONFIG
    
    # Remove from VLESS
    jq "del(.inbounds[1].settings.clients[] | select(.id == \"$USER_UUID\"))" $XRAY_CONFIG > /tmp/config.json
    mv /tmp/config.json $XRAY_CONFIG
    
    # Restart Xray
    systemctl restart xray
fi

# Remove profile
rm -f "$PROFILES_DIR/$USERNAME.txt"

log "User $USERNAME deleted successfully"
echo "✓ User deleted: $USERNAME"
