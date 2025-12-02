#!/bin/bash

################################################################################
# Squid User Management Script
################################################################################

set -e

PROFILES_DIR="/etc/mvpn/profiles/squid"
CONFIG_DIR="/etc/mvpn/config"
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

if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Username must contain only letters, numbers, dash, or underscore"
    exit 1
fi

# Check if user exists
if grep -q "^$USERNAME:" "$PASSWORD_FILE" 2>/dev/null; then
    echo "Error: User $USERNAME already exists"
    exit 1
fi

mkdir -p "$PROFILES_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Generate password
PASSWORD=$(openssl rand -base64 16)

# Add user to Squid password file
htpasswd -b "$PASSWORD_FILE" "$USERNAME" "$PASSWORD"

# Get server info
if [ -f "$CONFIG_DIR/server_ip" ]; then
    PUBLIC_IP=$(cat "$CONFIG_DIR/server_ip")
else
    PUBLIC_IP=$(curl -s https://api.ipify.org)
    echo "$PUBLIC_IP" > "$CONFIG_DIR/server_ip"
fi

SQUID_PORT=$(grep "^http_port" /etc/squid/squid.conf | awk '{print $2}')

# Create credentials file
cat > "$PROFILES_DIR/$USERNAME.txt" <<EOF
Squid Proxy Credentials
=======================

Username: $USERNAME
Password: $PASSWORD

Server: $PUBLIC_IP
Port: $SQUID_PORT

Connection String:
http://$USERNAME:$PASSWORD@$PUBLIC_IP:$SQUID_PORT

Browser Configuration:
- HTTP Proxy: $PUBLIC_IP:$SQUID_PORT
- HTTPS Proxy: $PUBLIC_IP:$SQUID_PORT
- Username: $USERNAME
- Password: $PASSWORD

cURL Example:
curl -x http://$USERNAME:$PASSWORD@$PUBLIC_IP:$SQUID_PORT https://api.ipify.org
EOF

chmod 600 "$PROFILES_DIR/$USERNAME.txt"

# Reload Squid
systemctl reload squid

log "User $USERNAME created successfully"
echo "✓ User created: $USERNAME"
echo "  Username: $USERNAME"
echo "  Password: $PASSWORD"
echo "  Credentials: $PROFILES_DIR/$USERNAME.txt"
echo "  Connection: http://$USERNAME:$PASSWORD@$PUBLIC_IP:$SQUID_PORT"
