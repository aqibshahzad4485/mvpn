#!/bin/bash

################################################################################
# Certificate Fetch Script (VPN Nodes)
# 
# This script fetches the latest wildcard certificates from your central storage.
# Run this on VPN nodes during installation and via cron.
################################################################################

set -e

# Configuration
CERTS_DIR="/etc/mvpn/certs"
REPO_URL=""  # Set this to your private repo URL if using git
REPO_DIR="/root/mvpn-certs-repo"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Certificate Fetch Manager${NC}"
echo -e "${GREEN}================================${NC}"

mkdir -p "$CERTS_DIR"
chmod 700 "$CERTS_DIR"

# Method 1: Git Pull (if configured)
if [ -n "$REPO_URL" ]; then
    echo -e "${YELLOW}Fetching from repository...${NC}"
    if [ ! -d "$REPO_DIR" ]; then
        git clone "$REPO_URL" "$REPO_DIR"
    else
        cd "$REPO_DIR"
        git pull
    fi
    
    # Copy certs
    if [ -f "$REPO_DIR/fullchain.pem" ]; then
        cp "$REPO_DIR/fullchain.pem" "$CERTS_DIR/"
        cp "$REPO_DIR/privkey.pem" "$CERTS_DIR/"
        chmod 600 "$CERTS_DIR/privkey.pem"
        echo -e "${GREEN}Certificates updated from repository.${NC}"
    else
        echo -e "${RED}Error: Certificates not found in repository!${NC}"
        exit 1
    fi

# Method 2: Manual Check (Default)
else
    echo -e "${YELLOW}Checking for manually placed certificates...${NC}"
    if [ -f "$CERTS_DIR/fullchain.pem" ] && [ -f "$CERTS_DIR/privkey.pem" ]; then
        echo -e "${GREEN}Certificates found in $CERTS_DIR${NC}"
    else
        echo -e "${RED}Certificates not found!${NC}"
        echo "Please copy 'fullchain.pem' and 'privkey.pem' to $CERTS_DIR"
        exit 1
    fi
fi

# Reload Services
echo -e "${YELLOW}Reloading services...${NC}"

# V2Ray/Xray
if systemctl is-active --quiet xray; then
    systemctl restart xray
    echo "✓ Xray restarted"
fi

# Nginx (if used)
if systemctl is-active --quiet nginx; then
    systemctl reload nginx
    echo "✓ Nginx reloaded"
fi

# Squid (if configured for HTTPS)
if systemctl is-active --quiet squid; then
    systemctl reload squid
    echo "✓ Squid reloaded"
fi

echo -e "${GREEN}Certificate update complete!${NC}"
