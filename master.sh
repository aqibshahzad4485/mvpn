#!/bin/bash

################################################################################
# MVPN Master Server Setup Script
# 
# This script sets up the master server by cloning both mvpn-backend and
# mvpn-scripts, generating certificates, and setting up the API backend.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/aqibshahzad4485/mvpn/main/master.sh | \
#     GITHUB_TOKEN=ghp_xxx \
#     CF_TOKEN=xxx 
#     bash
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}MVPN Master Server Setup${NC}"
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
    echo -e "${YELLOW}Usage: GITHUB_TOKEN=ghp_xxx CF_TOKEN=xxx bash master.sh${NC}"
    exit 1
fi

if [ -z "$CF_TOKEN" ]; then
    echo -e "${RED}Error: CF_TOKEN environment variable is required${NC}"
    echo -e "${YELLOW}Get token from: https://dash.cloudflare.com/profile/api-tokens${NC}"
    exit 1
fi

# Optional variables with defaults
VPN_DOMAIN="${VPN_DOMAIN:-vpn.aqibs.dev}"
CF_EMAIL="${CF_EMAIL:-aqib.shahzad4485@gmail.com}"
INSTALL_DIR="/opt/git"
GITHUB_ORG="aqibshahzad4485"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Install Directory: $INSTALL_DIR"
echo "  GitHub Org: $GITHUB_ORG"
echo "  VPN Domain: $VPN_DOMAIN"
echo "  Cloudflare Email: $CF_EMAIL"
echo ""

# Create install directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Clone mvpn-backend repository
echo -e "${YELLOW}Cloning mvpn-backend repository...${NC}"
if [ -d "mvpn-backend" ]; then
    echo -e "${YELLOW}mvpn-backend already exists, pulling latest changes...${NC}"
    cd mvpn-backend
    git pull
    cd ..
else
    git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_ORG}/mvpn-backend.git"
fi

# Clone mvpn-scripts repository
echo -e "${YELLOW}Cloning mvpn-scripts repository...${NC}"
if [ -d "mvpn-scripts" ]; then
    echo -e "${YELLOW}mvpn-scripts already exists, pulling latest changes...${NC}"
    cd mvpn-scripts
    git pull
    cd ..
else
    git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_ORG}/mvpn-scripts.git"
fi

# Create .env file for mvpn-backend
echo -e "${YELLOW}Creating mvpn-backend .env configuration...${NC}"
cat > mvpn-backend/.env <<EOF
# Cloudflare
CF_TOKEN="${CF_TOKEN}"
CF_EMAIL="${CF_EMAIL}"

# Domain
DOMAIN="${VPN_DOMAIN}"

# Paths
MVPN_SCRIPTS_PATH="${INSTALL_DIR}/mvpn-scripts"

# API Configuration
API_PORT=3000
API_SECRET="$(openssl rand -hex 32)"
EOF

chmod 600 mvpn-backend/.env

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
apt update
apt install -y certbot python3-certbot-dns-cloudflare git curl

# Generate certificates
echo -e "${YELLOW}Generating SSL certificates...${NC}"
cd mvpn-backend
chmod +x $INSTALL_DIR/mvpn-backend/scripts/certs/generate-certs.sh
bash $INSTALL_DIR/mvpn-backend/scripts/certs/generate-certs.sh

# Sync certificates to mvpn-scripts
echo -e "${YELLOW}Syncing certificates to mvpn-scripts...${NC}"
cd mvpn-scripts
chmod +x $INSTALL_DIR/mvpn-scripts/scripts/certs/sync-certs.sh
bash $INSTALL_DIR/mvpn-scripts/scripts/certs/sync-certs.sh

# Set up cron for certificate renewal (every month)
echo -e "${YELLOW}Setting up automatic certificate renewal...${NC}"
(crontab -l 2>/dev/null; echo "0 3 1 */1 * cd ${INSTALL_DIR}/mvpn-backend &&    bash $INSTALL_DIR/mvpn-backend/scripts/certs/check-certs.sh && bash $INSTALL_DIR/mvpn-scripts/scripts/certs/sync-certs.sh") | crontab -

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Master Server Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Repositories:${NC}"
echo "  Backend: ${INSTALL_DIR}/mvpn-backend"
echo "  Scripts: ${INSTALL_DIR}/mvpn-scripts"
echo ""
echo -e "${YELLOW}Certificates:${NC}"
echo "  Location: ${INSTALL_DIR}/mvpn-scripts/keys/"
echo "  Synced to GitHub: mvpn-scripts repository"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Set up srvlist API (see mvpn-backend/srvlist/README.md)"
echo "  2. Deploy VPN nodes using vpn.sh"
echo "  3. Monitor certificate expiry: ${INSTALL_DIR}/mvpn-backend/scripts/certs/check-certs.sh"
echo ""
