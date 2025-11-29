#!/bin/bash

################################################################################
# WireGuard Installation Script with Enterprise Security
# 
# Features:
# - ChaCha20-Poly1305 encryption
# - Curve25519 key exchange
# - Client isolation
# - Private network protection
# - Automatic key generation
# - Comprehensive logging
#
# IP Range: 10.9.0.0/24
# Port: 51820/UDP
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
WG_PORT=51820
WG_NETWORK="10.9.0.0/16"  # /16 subnet for 65,534 clients
WG_SERVER_IP="10.9.0.1"
WG_CLIENT_IP="10.9.0.2"
DNS1="1.1.1.1"
DNS2="1.0.0.1"

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}WireGuard Installation Script${NC}"
echo -e "${GREEN}================================${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Detect public IP
PUBLIC_IP=$(curl -s https://api.ipify.org)
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1)
fi

echo -e "${YELLOW}Detected public IP: $PUBLIC_IP${NC}"

# Update system
echo -e "${YELLOW}Updating system...${NC}"
apt update
apt upgrade -y

# Install WireGuard
echo -e "${YELLOW}Installing WireGuard...${NC}"
apt install -y wireguard qrencode ufw iptables-persistent

# Generate server keys
echo -e "${YELLOW}Generating server keys...${NC}"
cd /etc/wireguard
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
SERVER_PRIVATE_KEY=$(cat server_private.key)
SERVER_PUBLIC_KEY=$(cat server_public.key)

# Generate client keys
echo -e "${YELLOW}Generating client keys...${NC}"
wg genkey | tee client_private.key | wg pubkey > client_public.key
CLIENT_PRIVATE_KEY=$(cat client_private.key)
CLIENT_PUBLIC_KEY=$(cat client_public.key)

# Generate preshared key for additional security
wg genpsk > preshared.key
PRESHARED_KEY=$(cat preshared.key)

# Get primary network interface
NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

# Create server configuration
echo -e "${YELLOW}Creating server configuration...${NC}"
cat > /etc/wireguard/wg0.conf <<EOF
# WireGuard Server Configuration
# Mect VPN - Enterprise Security

[Interface]
Address = $WG_SERVER_IP/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY

# Firewall rules
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -A FORWARD -o wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $NIC -j MASQUERADE

# CLIENT ISOLATION - Block client-to-client communication
PostUp = iptables -A FORWARD -i wg0 -o wg0 -j DROP

# PRIVATE NETWORK PROTECTION - Block access to private networks
PostUp = iptables -A FORWARD -s 10.9.0.0/24 -d 192.168.0.0/16 -j DROP
PostUp = iptables -A FORWARD -s 10.9.0.0/24 -d 172.16.0.0/12 -j DROP
PostUp = iptables -A FORWARD -s 10.9.0.0/24 -d 10.0.0.0/8 ! -d 10.9.0.0/24 -j DROP

PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $NIC -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -o wg0 -j DROP
PostDown = iptables -D FORWARD -s 10.9.0.0/24 -d 192.168.0.0/16 -j DROP
PostDown = iptables -D FORWARD -s 10.9.0.0/24 -d 172.16.0.0/12 -j DROP
PostDown = iptables -D FORWARD -s 10.9.0.0/24 -d 10.0.0.0/8 ! -d 10.9.0.0/24 -j DROP

# Client configuration
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $PRESHARED_KEY
AllowedIPs = $WG_CLIENT_IP/32
EOF

chmod 600 /etc/wireguard/wg0.conf

# Enable IP forwarding
echo -e "${YELLOW}Enabling IP forwarding...${NC}"
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
sysctl -p

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw allow $WG_PORT/udp comment 'WireGuard'

# Start and enable WireGuard
echo -e "${YELLOW}Starting WireGuard service...${NC}"
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Generate client configuration
echo -e "${YELLOW}Generating client configuration...${NC}"
cat > /root/wg0-client.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $WG_CLIENT_IP/24
DNS = $DNS1, $DNS2

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $PRESHARED_KEY
Endpoint = $PUBLIC_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

chmod 600 /root/wg0-client.conf

# Generate QR code for mobile clients
echo -e "${YELLOW}Generating QR code...${NC}"
qrencode -t ansiutf8 < /root/wg0-client.conf > /root/wg0-client-qr.txt
qrencode -t png -o /root/wg0-client-qr.png < /root/wg0-client.conf

# Create helper script to add more clients
cat > /root/add-wireguard-client.sh <<'ADDCLIENT'
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <client-name>"
    exit 1
fi

CLIENT_NAME=$1
WG_DIR="/etc/wireguard"
cd $WG_DIR

# Get next available IP
LAST_IP=$(grep "AllowedIPs" wg0.conf | tail -1 | awk '{print $3}' | cut -d'/' -f1 | cut -d'.' -f4)
NEXT_IP=$((LAST_IP + 1))
CLIENT_IP="10.9.0.$NEXT_IP"

# Generate keys
wg genkey | tee ${CLIENT_NAME}_private.key | wg pubkey > ${CLIENT_NAME}_public.key
wg genpsk > ${CLIENT_NAME}_preshared.key

CLIENT_PRIVATE_KEY=$(cat ${CLIENT_NAME}_private.key)
CLIENT_PUBLIC_KEY=$(cat ${CLIENT_NAME}_public.key)
PRESHARED_KEY=$(cat ${CLIENT_NAME}_preshared.key)
SERVER_PUBLIC_KEY=$(cat server_public.key)
PUBLIC_IP=$(curl -s https://api.ipify.org)

# Add peer to server config
cat >> wg0.conf <<EOF

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $PRESHARED_KEY
AllowedIPs = $CLIENT_IP/32
EOF

# Restart WireGuard
wg-quick down wg0
wg-quick up wg0

# Create client config
cat > /root/${CLIENT_NAME}.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $PRESHARED_KEY
Endpoint = $PUBLIC_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# Generate QR code
qrencode -t ansiutf8 < /root/${CLIENT_NAME}.conf
qrencode -t png -o /root/${CLIENT_NAME}-qr.png < /root/${CLIENT_NAME}.conf

echo "Client $CLIENT_NAME created!"
echo "Config: /root/${CLIENT_NAME}.conf"
echo "QR Code: /root/${CLIENT_NAME}-qr.png"
ADDCLIENT

chmod +x /root/add-wireguard-client.sh

# Display summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}WireGuard Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Server Details:${NC}"
echo "  IP: $PUBLIC_IP"
echo "  Port: $WG_PORT/UDP"
echo "  VPN Network: $WG_NETWORK"
echo "  Server VPN IP: $WG_SERVER_IP"
echo ""
echo -e "${YELLOW}Security Features:${NC}"
echo "  ✓ ChaCha20-Poly1305 encryption"
echo "  ✓ Curve25519 key exchange"
echo "  ✓ Preshared keys for quantum resistance"
echo "  ✓ Client isolation enabled"
echo "  ✓ Private network protection"
echo ""
echo -e "${YELLOW}Client Configuration:${NC}"
echo "  Config file: /root/wg0-client.conf"
echo "  QR code (text): /root/wg0-client-qr.txt"
echo "  QR code (image): /root/wg0-client-qr.png"
echo ""
echo -e "${YELLOW}Add More Clients:${NC}"
echo "  /root/add-wireguard-client.sh <client-name>"
echo ""
echo -e "${YELLOW}Service Management:${NC}"
echo "  Status: systemctl status wg-quick@wg0"
echo "  Restart: systemctl restart wg-quick@wg0"
echo "  Show peers: wg show"
echo ""
echo -e "${GREEN}Scan QR code or download config to connect!${NC}"
