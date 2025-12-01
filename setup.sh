#!/bin/bash

################################################################################
# MVPN Master Setup Script
# 
# This is the main entry point for setting up the MVPN server.
# It will:
# - Create directory structure
# - Install all VPN protocols
# - Configure logging
# - Harden the server
# - Setup monitoring
#
# Installation:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/setup.sh | sudo bash
#
# Or:
#   git clone YOUR_REPO /tmp/mvpn
#   cd /tmp/mvpn
#   sudo ./setup.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories
MVPN_DIR="/usr/local/bin/mvpn"
PROFILES_DIR="/etc/mvpn/profiles"
LOG_DIR="/var/log/mvpn"
CONFIG_DIR="/etc/mvpn/config"

# Log file will be initialized after directory creation
SETUP_LOG=""

# Logging function
log() {
    if [ -n "$SETUP_LOG" ]; then
        echo -e "${2:-$NC}$1${NC}" | tee -a "$SETUP_LOG"
    else
        echo -e "${2:-$NC}$1${NC}"
    fi
}

log_error() {
    log "ERROR: $1" "$RED"
}

log_success() {
    log "✓ $1" "$GREEN"
}

log_info() {
    log "→ $1" "$BLUE"
}

log_warning() {
    log "⚠ $1" "$YELLOW"
}

# Banner
clear
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              MECT VPN - Master Setup Script               ║
║                                                           ║
║  This will install and configure all VPN protocols        ║
║  with enterprise-grade security on your server.           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF

echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Create directory structure FIRST (before any logging)
echo -e "${BLUE}→ Creating directory structure...${NC}"
mkdir -p "$MVPN_DIR"/{scripts,bin,lib}
mkdir -p "$PROFILES_DIR"/{openvpn,wireguard,squid,v2ray}
mkdir -p "$LOG_DIR"/{setup,openvpn,wireguard,squid,v2ray,security}
mkdir -p "$CONFIG_DIR"
chmod 755 "$MVPN_DIR"
chmod 750 "$PROFILES_DIR"
chmod 750 "$LOG_DIR"
chmod 750 "$CONFIG_DIR"

# Now initialize log file AFTER directory exists
SETUP_LOG="$LOG_DIR/setup/install-$(date +%Y%m%d-%H%M%S).log"

log_success "Directory structure created"

# Detect installation method
if [ -d "/tmp/mvpn" ]; then
    INSTALL_DIR="/tmp/mvpn"
elif [ -d "$(pwd)/scripts" ]; then
    INSTALL_DIR="$(pwd)"
else
    log_error "Cannot find installation files"
    exit 1
fi

log_info "Installation source: $INSTALL_DIR"

# Copy scripts
log_info "Installing scripts..."
cp -r "$INSTALL_DIR/scripts/"* "$MVPN_DIR/scripts/"
chmod +x "$MVPN_DIR/scripts/"*.sh
log_success "Scripts installed to $MVPN_DIR/scripts/"

# Get server info
PUBLIC_IP=$(curl -s https://api.ipify.org)
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1)
fi

log_info "Detected public IP: $PUBLIC_IP"

# Interactive menu
echo ""
log_info "Select installation type:"
echo "  1) Install all protocols (OpenVPN + WireGuard + Squid + V2Ray)"
echo "  2) Install OpenVPN only"
echo "  3) Install WireGuard only"
echo "  4) Install Squid Proxy only"
echo "  5) Install V2Ray/Xray only"
echo "  6) Custom selection"
echo "  7) Server hardening only"
echo ""
read -p "Enter choice [1-7]: " INSTALL_CHOICE

# Installation functions
install_openvpn() {
    log_info "Installing OpenVPN..."
    "$MVPN_DIR/scripts/install-openvpn.sh" 2>&1 | tee -a "$LOG_DIR/setup/openvpn-install.log"
    log_success "OpenVPN installed"
}

install_wireguard() {
    log_info "Installing WireGuard..."
    "$MVPN_DIR/scripts/install-wireguard.sh" 2>&1 | tee -a "$LOG_DIR/setup/wireguard-install.log"
    log_success "WireGuard installed"
}

install_squid() {
    log_info "Installing Squid Proxy..."
    "$MVPN_DIR/scripts/install-squid.sh" 2>&1 | tee -a "$LOG_DIR/setup/squid-install.log"
    log_success "Squid installed"
}

install_v2ray() {
    log_info "Installing V2Ray/Xray..."
    "$MVPN_DIR/scripts/install-v2ray.sh" 2>&1 | tee -a "$LOG_DIR/setup/v2ray-install.log"
    log_success "V2Ray installed"
}

harden_server() {
    log_info "Hardening server..."
    "$MVPN_DIR/scripts/harden-server.sh" 2>&1 | tee -a "$LOG_DIR/setup/hardening.log"
    log_success "Server hardened"
}

# Execute based on choice
case $INSTALL_CHOICE in
    1)
        install_openvpn
        install_wireguard
        install_squid
        install_v2ray
        harden_server
        ;;
    2)
        install_openvpn
        harden_server
        ;;
    3)
        install_wireguard
        harden_server
        ;;
    4)
        install_squid
        harden_server
        ;;
    5)
        install_v2ray
        harden_server
        ;;
    6)
        echo "Select protocols to install (y/n):"
        read -p "OpenVPN? " INST_OV
        read -p "WireGuard? " INST_WG
        read -p "Squid? " INST_SQ
        read -p "V2Ray? " INST_V2
        
        [ "$INST_OV" = "y" ] && install_openvpn
        [ "$INST_WG" = "y" ] && install_wireguard
        [ "$INST_SQ" = "y" ] && install_squid
        [ "$INST_V2" = "y" ] && install_v2ray
        harden_server
        ;;
    7)
        harden_server
        ;;
    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

# Create management commands
log_info "Creating management commands..."

cat > /usr/local/bin/mvpn-status <<'EOF'
#!/bin/bash
source /usr/local/bin/mvpn/lib/common.sh
show_status
EOF

cat > /usr/local/bin/mvpn-add-user <<'EOF'
#!/bin/bash
source /usr/local/bin/mvpn/lib/common.sh
add_user "$@"
EOF

cat > /usr/local/bin/mvpn-list-users <<'EOF'
#!/bin/bash
source /usr/local/bin/mvpn/lib/common.sh
list_users "$@"
EOF

cat > /usr/local/bin/mvpn-delete-user <<'EOF'
#!/bin/bash
source /usr/local/bin/mvpn/lib/common.sh
delete_user "$@"
EOF

chmod +x /usr/local/bin/mvpn-*

log_success "Management commands created"

# Create common library
cat > "$MVPN_DIR/lib/common.sh" <<'COMMONLIB'
#!/bin/bash

# Common functions for MVPN

PROFILES_DIR="/etc/mvpn/profiles"
LOG_DIR="/var/log/mvpn"

show_status() {
    echo "MECT VPN Server Status"
    echo "======================"
    echo ""
    systemctl is-active openvpn@server 2>/dev/null && echo "✓ OpenVPN: Running" || echo "✗ OpenVPN: Stopped"
    systemctl is-active wg-quick@wg0 2>/dev/null && echo "✓ WireGuard: Running" || echo "✗ WireGuard: Stopped"
    systemctl is-active squid 2>/dev/null && echo "✓ Squid: Running" || echo "✗ Squid: Stopped"
    systemctl is-active xray 2>/dev/null && echo "✓ V2Ray: Running" || echo "✗ V2Ray: Stopped"
    echo ""
    echo "Profiles: $PROFILES_DIR"
    echo "Logs: $LOG_DIR"
}

add_user() {
    echo "Add User - Select Protocol:"
    echo "1) OpenVPN"
    echo "2) WireGuard"
    echo "3) Squid"
    echo "4) V2Ray"
    read -p "Choice: " proto
    read -p "Username: " username
    
    case $proto in
        1) /usr/local/bin/mvpn/scripts/mgmt/add-openvpn-user.sh "$username" ;;
        2) /usr/local/bin/mvpn/scripts/mgmt/add-wireguard-user.sh "$username" ;;
        3) /usr/local/bin/mvpn/scripts/mgmt/add-squid-user.sh "$username" ;;
        4) /usr/local/bin/mvpn/scripts/mgmt/add-v2ray-user.sh "$username" ;;
        *) echo "Invalid choice" ;;
    esac
}

list_users() {
    echo "VPN Users:"
    echo ""
    [ -d "$PROFILES_DIR/openvpn" ] && echo "OpenVPN:" && ls -1 "$PROFILES_DIR/openvpn" 2>/dev/null
    [ -d "$PROFILES_DIR/wireguard" ] && echo "WireGuard:" && ls -1 "$PROFILES_DIR/wireguard" 2>/dev/null
    [ -d "$PROFILES_DIR/v2ray" ] && echo "V2Ray:" && ls -1 "$PROFILES_DIR/v2ray" 2>/dev/null
}

delete_user() {
    echo "Delete User - Not yet implemented"
}
COMMONLIB

chmod +x "$MVPN_DIR/lib/common.sh"

# Save installation info
cat > "$CONFIG_DIR/install-info.json" <<EOF
{
  "installed_at": "$(date -Iseconds)",
  "public_ip": "$PUBLIC_IP",
  "protocols": {
    "openvpn": $(systemctl is-active openvpn@server 2>/dev/null && echo "true" || echo "false"),
    "wireguard": $(systemctl is-active wg-quick@wg0 2>/dev/null && echo "true" || echo "false"),
    "squid": $(systemctl is-active squid 2>/dev/null && echo "true" || echo "false"),
    "v2ray": $(systemctl is-active xray 2>/dev/null && echo "true" || echo "false")
  },
  "directories": {
    "scripts": "$MVPN_DIR",
    "profiles": "$PROFILES_DIR",
    "logs": "$LOG_DIR",
    "config": "$CONFIG_DIR"
  }
}
EOF

# Final summary
echo ""
echo ""
log_success "═══════════════════════════════════════════════════════════"
log_success "           MECT VPN Installation Complete!                  "
log_success "═══════════════════════════════════════════════════════════"
echo ""
log_info "Server Information:"
echo "  Public IP: $PUBLIC_IP"
echo "  Installation: $MVPN_DIR"
echo "  Profiles: $PROFILES_DIR"
echo "  Logs: $LOG_DIR"
echo ""
log_info "Management Commands:"
echo "  mvpn-status          - Show server status"
echo "  mvpn-add-user        - Add new VPN user"
echo "  mvpn-list-users      - List all users"
echo "  mvpn-delete-user     - Delete a user"
echo ""
log_info "Profile Locations:"
[ -d "$PROFILES_DIR/openvpn" ] && echo "  OpenVPN: $PROFILES_DIR/openvpn/"
[ -d "$PROFILES_DIR/wireguard" ] && echo "  WireGuard: $PROFILES_DIR/wireguard/"
[ -d "$PROFILES_DIR/squid" ] && echo "  Squid: $PROFILES_DIR/squid/"
[ -d "$PROFILES_DIR/v2ray" ] && echo "  V2Ray: $PROFILES_DIR/v2ray/"
echo ""
log_info "Installation Log: $SETUP_LOG"
echo ""
log_success "Server is ready for VPN connections!"
echo ""
