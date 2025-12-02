#!/bin/bash

################################################################################
# Certificate Generation Script (Backend Server)
# 
# This script manages wildcard SSL certificates.
# It checks for existing Let's Encrypt certs, generates if missing,
# and copies them to the local 'keys' directory for distribution.
################################################################################

set -e

# Configuration
DOMAIN=${DOMAIN:-"vpn.aqibs.dev"}
EMAIL=${EMAIL:-"admin@aqibs.dev"}

# Directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
KEYS_DIR="$SCRIPT_DIR/keys"
LE_DIR="/etc/letsencrypt/live/$DOMAIN"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Certificate Manager${NC}"
echo -e "${GREEN}================================${NC}"

mkdir -p "$KEYS_DIR"

# Load environment variables if not already set
if [ -z "$CF_Token" ] || [ -z "$CF_Email" ]; then
    if [ -f /etc/environment ]; then
        echo -e "${YELLOW}Loading credentials from /etc/environment...${NC}"
        export $(grep -E '^(CF_Token|CF_Email)=' /etc/environment | xargs)
    fi
fi

# Check if certs exist
if [ -f "$LE_DIR/fullchain.pem" ] && [ -f "$LE_DIR/privkey.pem" ]; then
    echo -e "${GREEN}✓ Existing certificates found in $LE_DIR${NC}"
else
    echo -e "${YELLOW}Certificates not found. Generating new ones...${NC}"
    
    # Check for Cloudflare credentials after loading
    if [ -z "$CF_Token" ] || [ -z "$CF_Email" ]; then
        echo -e "${RED}Error: Cloudflare credentials not found!${NC}"
        echo "Please add CF_Token and CF_Email to /etc/environment"
        echo ""
        echo "Example:"
        echo '  CF_Token="your_token_here"'
        echo '  CF_Email="your@email.com"'
        exit 1
    fi

    # Create credentials file for certbot
    mkdir -p ~/.secrets/certbot
    cat > ~/.secrets/certbot/cloudflare.ini <<EOF
dns_cloudflare_api_token = $CF_Token
EOF
    chmod 600 ~/.secrets/certbot/cloudflare.ini

    # Generate Wildcard Certificate
    certbot certonly \
      --dns-cloudflare \
      --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
      --dns-cloudflare-propagation-seconds 60 \
      --non-interactive \
      --agree-tos \
      --email "$EMAIL" \
      -d "$DOMAIN" \
      -d "*.$DOMAIN"
      
    if [ ! -f "$LE_DIR/fullchain.pem" ]; then
        echo -e "${RED}Error: Certificate generation failed!${NC}"
        exit 1
    fi
fi

# Copy to keys directory
echo -e "${YELLOW}Copying certificates to $KEYS_DIR...${NC}"
cp "$LE_DIR/fullchain.pem" "$KEYS_DIR/"
cp "$LE_DIR/privkey.pem" "$KEYS_DIR/"

# Check Expiry
echo -e "${YELLOW}Checking certificate expiry...${NC}"
EXPIRY=$(openssl x509 -enddate -noout -in "$KEYS_DIR/fullchain.pem" | cut -d= -f2)
echo -e "${GREEN}Certificate Expires: $EXPIRY${NC}"

# Instructions
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Action Required${NC}"
echo -e "${GREEN}================================${NC}"
echo "1. Commit and push the updated keys to your repository:"
echo -e "${YELLOW}   git add scripts/certs/keys/*${NC}"
echo -e "${YELLOW}   git commit -m 'Update SSL certificates (Expires: $EXPIRY)'${NC}"
echo -e "${YELLOW}   git push${NC}"
echo ""
echo "2. On your VPN servers, pull the changes and run setup/update:"
echo -e "${YELLOW}   cd /tmp/mvpn && git pull${NC}"
echo -e "${YELLOW}   ./scripts/setup.sh 1${NC}"
echo ""
