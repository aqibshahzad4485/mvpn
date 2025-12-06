#!/bin/bash

################################################################################
# MVPN VPN Server Deployment Script
# 
# This script deploys a VPN server by cloning mvpn-scripts and running setup.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/aqibshahzad4485/mvpn/main/vpn.sh | \
#     GITHUB_TOKEN=ghp_xxx \
#     MASTER_API_URL=https://api.yourdomain.com \
#     MASTER_API_TOKEN=xxx \
#     bash
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}MVPN VPN Server Deployment${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Validate required environment variables
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}Error: GITHUB_TOKEN environment variable is required${NC}"
    echo -e "${YELLOW}Usage: GITHUB_TOKEN=ghp_xxx bash vpn.sh${NC}"
    exit 1
fi

# Optional variables with defaults
MASTER_API_URL="${MASTER_API_URL:-}"
MASTER_API_TOKEN="${MASTER_API_TOKEN:-}"
INSTALL_DIR="/opt/git"
GITHUB_ORG="aqibshahzad4485"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Install Directory: $INSTALL_DIR"
echo "  GitHub Org: $GITHUB_ORG"
[ -n "$MASTER_API_URL" ] && echo "  Master API: $MASTER_API_URL"
echo ""

# Create install directory
mkdir -p "$INSTALL_DIR"

# Clone mvpn-scripts repository
echo -e "${YELLOW}Cloning mvpn-scripts repository...${NC}"
cd "$INSTALL_DIR"

if [ -d "mvpn-scripts" ]; then
    echo -e "${YELLOW}mvpn-scripts already exists, pulling latest changes...${NC}"
    cd mvpn-scripts
    git pull
else
    git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_ORG}/mvpn-scripts.git"
    cd mvpn-scripts
fi

# Create .env file
echo -e "${YELLOW}Creating .env configuration...${NC}"
cat > .env <<EOF
# Master Server
MASTER_API_URL="${MASTER_API_URL}"
MASTER_API_TOKEN="${MASTER_API_TOKEN}"

# GitHub
GITHUB_TOKEN="${GITHUB_TOKEN}"
EOF

chmod 600 .env

# Run setup script
echo -e "${YELLOW}Running VPN setup...${NC}"
echo ""
./setup.sh

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}VPN Server Deployment Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Check service status: systemctl status openvpn@server wg-quick@wg0 squid xray"
echo "  2. View logs: tail -f /var/log/mvpn/setup.log"
echo "  3. Add users: /usr/local/bin/mvpn/scripts/mgmt/add-*-user.sh username"
echo "  4. Update certificates: /opt/git/mvpn-scripts/update-certs.sh"
echo ""
