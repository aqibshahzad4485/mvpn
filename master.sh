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

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source common environment helper library
source "$SCRIPT_DIR/common-env.sh"

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

# Load .env file if it exists
load_env_file || echo -e "${YELLOW}No .env file found, will use environment variables or prompt for values${NC}"

# Set defaults for optional variables
set_default "VPN_DOMAIN" "vpn.aqibs.dev"
set_default "CF_EMAIL" "aqib.shahzad4485@gmail.com"
set_default "INSTALL_DIR" "/opt/git"
set_default "GITHUB_ORG" "aqibshahzad4485"

# Prompt for required variables if not set
echo ""
echo -e "${YELLOW}Checking required configuration...${NC}"
prompt_if_missing "GITHUB_TOKEN" "GitHub Personal Access Token (with repo access)" "" "true" || exit 1
prompt_if_missing "CF_TOKEN" "Cloudflare API Token" "" "true" || exit 1

# Prompt for optional variables (with defaults already set)
prompt_if_missing "VPN_DOMAIN" "VPN Domain" "$VPN_DOMAIN"
prompt_if_missing "CF_EMAIL" "Cloudflare Email" "$CF_EMAIL"

# Validate all required variables are set
validate_required "GITHUB_TOKEN" "CF_TOKEN" "VPN_DOMAIN" "CF_EMAIL" || exit 1

echo ""
show_config "INSTALL_DIR" "GITHUB_ORG" "VPN_DOMAIN" "CF_EMAIL"

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
