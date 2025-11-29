#!/bin/bash

################################################################################
# Squid User Deletion Script
################################################################################

set -e

PROFILES_DIR="/etc/mvpn/profiles/squid"
LOG_FILE="/var/log/mvpn/user-management.log"
PASSWORD_FILE="/etc/squid/passwords"

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

if ! grep -q "^$USERNAME:" "$PASSWORD_FILE" 2>/dev/null; then
    echo "Error: User $USERNAME does not exist"
    exit 1
fi

# Remove from password file
htpasswd -D "$PASSWORD_FILE" "$USERNAME"

# Remove credentials file
rm -f "$PROFILES_DIR/$USERNAME.txt"

# Reload Squid
systemctl reload squid

log "User $USERNAME deleted successfully"
echo "✓ User deleted: $USERNAME"
