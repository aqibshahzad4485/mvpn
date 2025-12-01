#!/bin/bash

################################################################################
# Centralized Firewall Configuration
# 
# This script configures UFW for all installed VPN protocols
# Run this after installing all protocols
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Configuring Firewall${NC}"
echo -e "${GREEN}================================${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Reset UFW
echo -e "${YELLOW}Resetting firewall...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH (always needed)
echo -e "${YELLOW}Adding SSH rules...${NC}"
ufw allow 22/tcp comment 'SSH'
ufw limit 22/tcp

# Check which protocols are installed and add their rules
echo -e "${YELLOW}Detecting installed protocols...${NC}"

# OpenVPN
if systemctl is-active --quiet openvpn@server 2>/dev/null || [ -f /etc/openvpn/server.conf ]; then
    echo -e "${GREEN}✓ OpenVPN detected${NC}"
    OPENVPN_PORT=$(grep "^port" /etc/openvpn/server.conf 2>/dev/null | awk '{print $2}' || echo "1194")
    OPENVPN_PROTO=$(grep "^proto" /etc/openvpn/server.conf 2>/dev/null | awk '{print $2}' || echo "udp")
    ufw allow ${OPENVPN_PORT}/${OPENVPN_PROTO} comment 'OpenVPN'
    echo "  Added: ${OPENVPN_PORT}/${OPENVPN_PROTO}"
fi

# WireGuard
if systemctl is-active --quiet wg-quick@wg0 2>/dev/null || [ -f /etc/wireguard/wg0.conf ]; then
    echo -e "${GREEN}✓ WireGuard detected${NC}"
    WG_PORT=$(grep "^ListenPort" /etc/wireguard/wg0.conf 2>/dev/null | awk '{print $3}' || echo "51820")
    ufw allow ${WG_PORT}/udp comment 'WireGuard'
    echo "  Added: ${WG_PORT}/udp"
fi

# Squid
if systemctl is-active --quiet squid 2>/dev/null || [ -f /etc/squid/squid.conf ]; then
    echo -e "${GREEN}✓ Squid detected${NC}"
    SQUID_PORT=$(grep "^http_port" /etc/squid/squid.conf 2>/dev/null | awk '{print $2}' || echo "3128")
    ufw allow ${SQUID_PORT}/tcp comment 'Squid Proxy'
    echo "  Added: ${SQUID_PORT}/tcp"
fi

# V2Ray/Xray
if systemctl is-active --quiet xray 2>/dev/null || [ -f /usr/local/etc/xray/config.json ]; then
    echo -e "${GREEN}✓ V2Ray/Xray detected${NC}"
    ufw allow 80/tcp comment 'HTTP (Let\'s Encrypt)'
    ufw allow 443/tcp comment 'HTTPS (V2Ray)'
    echo "  Added: 80/tcp, 443/tcp"
fi

# Enable UFW
echo -e "${YELLOW}Enabling firewall...${NC}"
echo "y" | ufw enable

# Display status
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Firewall Configuration Complete${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Active Rules:${NC}"
ufw status verbose

echo ""
echo -e "${GREEN}All VPN ports are now open!${NC}"
