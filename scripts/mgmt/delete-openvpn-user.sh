#!/bin/bash

################################################################################
# OpenVPN User Deletion Script
# 
# Usage:
#   ./delete-openvpn-user.sh <username>
#   ./delete-openvpn-user.sh john
#
# Features:
# - Revokes certificate
# - Marks IP as available for reuse
# - Removes profile
# - Non-interactive
################################################################################

set -e

# Directories
PROFILES_DIR="/etc/mvpn/profiles/openvpn"
CONFIG_DIR="/etc/mvpn/config"
LOG_FILE="/var/log/mvpn/user-management.log"
IP_DB="$CONFIG_DIR/openvpn-ips.db"
EASYRSA_DIR="/etc/openvpn/easy-rsa"

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

# Check if user exists
if [ ! -f "$PROFILES_DIR/$USERNAME.ovpn" ]; then
    echo "Error: User $USERNAME does not exist"
    exit 1
fi

# Get user's IP
USER_IP=$(grep " $USERNAME " "$IP_DB" | awk '{print $1}')

# Revoke certificate
log "Revoking certificate for $USERNAME..."
cd "$EASYRSA_DIR"
./easyrsa --batch revoke "$USERNAME"
./easyrsa gen-crl

# Copy CRL to OpenVPN directory
cp "$EASYRSA_DIR/pki/crl.pem" /etc/openvpn/

# Remove profile
rm -f "$PROFILES_DIR/$USERNAME.ovpn"
log "Removed profile for $USERNAME"

# Mark IP as deleted (available for reuse)
if [ -n "$USER_IP" ]; then
    sed -i "s/^$USER_IP $USERNAME ACTIVE/$USER_IP DELETED DELETED/" "$IP_DB"
    log "Marked IP $USER_IP as available for reuse"
fi

# Restart OpenVPN to apply CRL
systemctl restart openvpn@server

# Success
log "User $USERNAME deleted successfully"
echo "✓ User deleted: $USERNAME"
echo "  IP $USER_IP is now available for reuse"
echo "  Certificate revoked"
