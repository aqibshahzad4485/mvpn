#!/bin/bash

################################################################################
# Install All VPN Protocols Script
# 
# This script installs all VPN protocols:
# - OpenVPN
# - WireGuard
# - Squid Proxy
# - V2Ray/Xray
#
# Plus server hardening
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Install All VPN Protocols${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Make all scripts executable
chmod +x $SCRIPT_DIR/*.sh

echo -e "${YELLOW}This will install:${NC}"
echo "  1. OpenVPN (Port 1194/UDP)"
echo "  2. WireGuard (Port 51820/UDP)"
echo "  3. Squid Proxy (Port 3128/TCP)"
echo "  4. V2Ray/Xray (Port 443/TCP)"
echo "  5. Server Hardening"
echo ""
read -p "Continue? (y/N): " CONTINUE

if [ "$CONTINUE" != "y" ]; then
    echo "Installation cancelled."
    exit 0
fi

# Install protocols
echo -e "${GREEN}Installing OpenVPN...${NC}"
$SCRIPT_DIR/install-openvpn.sh

echo -e "${GREEN}Installing WireGuard...${NC}"
$SCRIPT_DIR/install-wireguard.sh

echo -e "${GREEN}Installing Squid Proxy...${NC}"
$SCRIPT_DIR/install-squid.sh

echo -e "${GREEN}Installing V2Ray/Xray...${NC}"
$SCRIPT_DIR/install-v2ray.sh

echo -e "${GREEN}Hardening Server...${NC}"
$SCRIPT_DIR/harden-server.sh

# Display summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All Protocols Installed Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Installed Protocols:${NC}"
echo "  ✓ OpenVPN (1194/UDP)"
echo "  ✓ WireGuard (51820/UDP)"
echo "  ✓ Squid Proxy (3128/TCP)"
echo "  ✓ V2Ray/Xray (443/TCP)"
echo ""
echo -e "${YELLOW}Client Configurations:${NC}"
echo "  OpenVPN: /root/client.ovpn"
echo "  WireGuard: /root/wg0-client.conf"
echo "  Squid: /root/squid-credentials.txt"
echo "  V2Ray: /root/v2ray-links.txt"
echo ""
echo -e "${YELLOW}Service Status:${NC}"
echo "  systemctl status openvpn@server"
echo "  systemctl status wg-quick@wg0"
echo "  systemctl status squid"
echo "  systemctl status xray"
echo ""
echo -e "${GREEN}Server is ready for VPN connections!${NC}"
