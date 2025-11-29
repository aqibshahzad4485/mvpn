#!/bin/bash

################################################################################
# Server Hardening Script
# 
# Security measures:
# - SSH hardening
# - Firewall configuration
# - fail2ban setup
# - Kernel parameter tuning
# - Automatic security updates
# - Disable unnecessary services
# - System monitoring
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Server Hardening Script${NC}"
echo -e "${GREEN}================================${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Update system
echo -e "${YELLOW}Updating system...${NC}"
apt update
apt upgrade -y

# Install security tools
echo -e "${YELLOW}Installing security tools...${NC}"
apt install -y ufw fail2ban unattended-upgrades apt-listchanges logwatch

# 1. SSH Hardening
echo -e "${YELLOW}Hardening SSH...${NC}"

# Backup original SSH config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Configure SSH
cat > /etc/ssh/sshd_config <<EOF
# SSH Server Configuration - Hardened
# Mect VPN Security

# Network
Port 22
AddressFamily inet
ListenAddress 0.0.0.0

# Authentication
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Security
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2

# Disable dangerous features
X11Forwarding no
PermitTunnel no
AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Subsystems
Subsystem sftp /usr/lib/openssh/sftp-server

# Banner
Banner /etc/ssh/banner
EOF

# Create SSH banner
cat > /etc/ssh/banner <<EOF
***************************************************************************
                    AUTHORIZED ACCESS ONLY
                    
This system is for authorized use only. Unauthorized access is prohibited
and will be prosecuted to the fullest extent of the law.

All activities on this system are monitored and recorded.
***************************************************************************
EOF

systemctl restart sshd

# 2. Configure fail2ban
echo -e "${YELLOW}Configuring fail2ban...${NC}"

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = admin@aqibs.dev
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
EOF

systemctl restart fail2ban

# 3. Firewall Configuration
echo -e "${YELLOW}Configuring firewall...${NC}"

# Reset UFW
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH with rate limiting
ufw limit 22/tcp comment 'SSH - Rate Limited'

# Enable UFW
echo "y" | ufw enable

# 4. Kernel Parameter Tuning
echo -e "${YELLOW}Tuning kernel parameters...${NC}"

cat >> /etc/sysctl.conf <<EOF

# Mect VPN - Security Hardening

# IP Forwarding (required for VPN)
net.ipv4.ip_forward = 1

# Disable IPv6 (optional)
#net.ipv6.conf.all.disable_ipv6 = 1
#net.ipv6.conf.default.disable_ipv6 = 1

# Prevent IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable ICMP redirect acceptance
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Disable ICMP redirect sending
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Ignore ICMP ping requests
#net.ipv4.icmp_echo_ignore_all = 1

# Ignore broadcast pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Enable TCP SYN cookies (DDoS protection)
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Performance tuning
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr

# Connection tracking
net.netfilter.nf_conntrack_max = 1000000
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
EOF

sysctl -p

# 5. Automatic Security Updates
echo -e "${YELLOW}Configuring automatic security updates...${NC}"

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

systemctl restart unattended-upgrades

# 6. Disable Unnecessary Services
echo -e "${YELLOW}Disabling unnecessary services...${NC}"

# List of services to disable (if they exist)
SERVICES_TO_DISABLE=(
    "bluetooth"
    "cups"
    "avahi-daemon"
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
    if systemctl is-enabled $service 2>/dev/null; then
        systemctl disable $service
        systemctl stop $service
        echo "Disabled: $service"
    fi
done

# 7. Setup Logwatch
echo -e "${YELLOW}Configuring logwatch...${NC}"

cat > /etc/cron.daily/00logwatch <<EOF
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto admin@aqibs.dev --detail high
EOF

chmod +x /etc/cron.daily/00logwatch

# 8. Create monitoring script
echo -e "${YELLOW}Creating monitoring script...${NC}"

cat > /root/server-status.sh <<'MONITOR'
#!/bin/bash

echo "================================"
echo "Server Status Report"
echo "================================"
echo ""

echo "System Information:"
echo "  Hostname: $(hostname)"
echo "  Uptime: $(uptime -p)"
echo "  Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

echo "Memory Usage:"
free -h
echo ""

echo "Disk Usage:"
df -h | grep -E '^/dev/'
echo ""

echo "Network Connections:"
echo "  Active: $(ss -tun | wc -l)"
echo "  Listening: $(ss -tln | wc -l)"
echo ""

echo "VPN Services:"
systemctl is-active openvpn@server 2>/dev/null && echo "  ✓ OpenVPN: Running" || echo "  ✗ OpenVPN: Stopped"
systemctl is-active wg-quick@wg0 2>/dev/null && echo "  ✓ WireGuard: Running" || echo "  ✗ WireGuard: Stopped"
systemctl is-active squid 2>/dev/null && echo "  ✓ Squid: Running" || echo "  ✗ Squid: Stopped"
systemctl is-active xray 2>/dev/null && echo "  ✓ Xray: Running" || echo "  ✗ Xray: Stopped"
echo ""

echo "Security:"
echo "  fail2ban: $(systemctl is-active fail2ban)"
echo "  UFW: $(ufw status | head -1)"
echo "  Banned IPs: $(fail2ban-client status sshd 2>/dev/null | grep 'Currently banned' | awk '{print $4}' || echo '0')"
echo ""

echo "Last 5 SSH Logins:"
last -5 -a
echo ""
MONITOR

chmod +x /root/server-status.sh

# 9. Create security audit script
cat > /root/security-audit.sh <<'AUDIT'
#!/bin/bash

echo "================================"
echo "Security Audit Report"
echo "================================"
echo ""

echo "1. Checking for failed SSH attempts..."
grep "Failed password" /var/log/auth.log | tail -10
echo ""

echo "2. Checking fail2ban status..."
fail2ban-client status
echo ""

echo "3. Checking open ports..."
ss -tulpn
echo ""

echo "4. Checking firewall rules..."
ufw status verbose
echo ""

echo "5. Checking for pending updates..."
apt list --upgradable
echo ""

echo "6. Checking system logs for errors..."
journalctl -p err -n 20 --no-pager
echo ""
AUDIT

chmod +x /root/security-audit.sh

# Display summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Server Hardening Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Security Measures Applied:${NC}"
echo "  ✓ SSH hardened (key-based auth recommended)"
echo "  ✓ fail2ban configured"
echo "  ✓ Firewall (UFW) enabled"
echo "  ✓ Kernel parameters tuned"
echo "  ✓ Automatic security updates enabled"
echo "  ✓ Unnecessary services disabled"
echo "  ✓ Monitoring scripts created"
echo ""
echo -e "${YELLOW}Monitoring Scripts:${NC}"
echo "  Server Status: /root/server-status.sh"
echo "  Security Audit: /root/security-audit.sh"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Setup SSH key authentication"
echo "  2. Disable password authentication in SSH"
echo "  3. Change SSH port (optional)"
echo "  4. Setup monitoring alerts"
echo "  5. Regular security audits"
echo ""
echo -e "${GREEN}Server is now hardened and secure!${NC}"
