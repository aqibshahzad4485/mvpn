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
echo -e "${GREEN}MVPN VPN Server Deployment${NC}"
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
set_default "INSTALL_DIR" "/opt/git"
set_default "GITHUB_ORG" "aqibshahzad4485"
set_default "MASTER_API_URL" ""
set_default "MASTER_API_TOKEN" ""

# Prompt for required variables if not set
echo ""
echo -e "${YELLOW}Checking required configuration...${NC}"
prompt_if_missing "GITHUB_TOKEN" "GitHub Personal Access Token (read access to mvpn-scripts)" "" "true" || exit 1

# Prompt for optional variables
if [ -z "$MASTER_API_URL" ]; then
    echo -e "${YELLOW}Master API URL not set. VPN monitoring will be disabled.${NC}"
    if is_interactive && confirm_action "Do you want to configure master API now?"; then
        prompt_if_missing "MASTER_API_URL" "Master API URL (e.g., https://api.yourdomain.com)"
        prompt_if_missing "MASTER_API_TOKEN" "Master API Token" "" "true"
    fi
fi

# Validate required variables
validate_required "GITHUB_TOKEN" || exit 1

echo ""
show_config "INSTALL_DIR" "GITHUB_ORG" "MASTER_API_URL"

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
