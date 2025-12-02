# VPN Protocol Installation & Management Scripts

## 📋 Overview

Production-ready scripts for installing and managing multiple VPN protocols with enterprise-grade security.

## 🚀 Quick Start

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/aqibshahzad4485/mvpn/main/setup.sh | sudo bash
```

### Manual Installation

```bash
git clone https://github.com/aqibshahzad4485/mvpn.git /tmp/mvpn
cd /tmp/mvpn
sudo ./setup.sh
```

## 📁 Directory Structure

```
/usr/local/bin/mvpn/scripts/   # Installation scripts
├── install-openvpn.sh
├── install-wireguard.sh
├── install-squid.sh
├── install-v2ray.sh
├── install-all.sh
├── harden-server.sh
└── mgmt/                       # User management
    ├── add-openvpn-user.sh
    ├── delete-openvpn-user.sh
    ├── add-wireguard-user.sh
    ├── delete-wireguard-user.sh
    ├── add-squid-user.sh
    ├── delete-squid-user.sh
    ├── add-v2ray-user.sh
    └── delete-v2ray-user.sh

/etc/mvpn/                      # Configuration
├── profiles/                   # User profiles
│   ├── openvpn/               # .ovpn files
│   ├── wireguard/             # .conf files
│   ├── squid/                 # credentials
│   └── v2ray/                 # links
└── config/                     # Server config
    ├── openvpn-ips.db         # IP allocation tracking
    ├── wireguard-ips.db
    └── install-info.json

/var/log/mvpn/                  # Centralized logging
├── setup.log                   # Installation log
├── user-management.log         # User add/delete log
├── openvpn.log                 # OpenVPN log
├── wireguard.log               # WireGuard log
├── squid-access.log            # Squid access
├── squid-cache.log             # Squid cache
├── v2ray-access.log            # V2Ray access
└── v2ray-error.log             # V2Ray errors
```

## 🔐 Protocols

| Protocol | Port | IP Range | Max Users | Use Case |
|----------|------|----------|-----------|----------|
| **OpenVPN** | 1194/UDP | 10.8.0.0/16 | 65,534 | Universal compatibility |
| **WireGuard** | 51820/UDP | 10.9.0.0/16 | 65,534 | Modern, fast VPN |
| **Squid** | 3128/TCP | N/A | Unlimited | HTTP/HTTPS proxy |
| **V2Ray** | 443/TCP | 10.10.0.0/16 | 65,534 | Censorship circumvention |

### IP Range Benefits (/16 Subnets)

- **65,534 users per protocol** (vs 254 with /24)
- **Intelligent IP reuse** - Deleted user IPs are recycled
- **Automatic allocation** - No manual IP management
- **Scalable** - Enterprise-ready capacity

## 👥 User Management

### Add Users

All user management scripts are **non-interactive** and can be run remotely:

```bash
# OpenVPN
/usr/local/bin/mvpn/scripts/mgmt/add-openvpn-user.sh john

# WireGuard  
/usr/local/bin/mvpn/scripts/mgmt/add-wireguard-user.sh jane

# Squid
/usr/local/bin/mvpn/scripts/mgmt/add-squid-user.sh alice

# V2Ray
/usr/local/bin/mvpn/scripts/mgmt/add-v2ray-user.sh bob
```

### Delete Users

```bash
# OpenVPN
/usr/local/bin/mvpn/scripts/mgmt/delete-openvpn-user.sh john

# WireGuard
/usr/local/bin/mvpn/scripts/mgmt/delete-wireguard-user.sh jane

# Squid
/usr/local/bin/mvpn/scripts/mgmt/delete-squid-user.sh alice

# V2Ray
/usr/local/bin/mvpn/scripts/mgmt/delete-v2ray-user.sh bob
```

### Intelligent IP Allocation

**Features:**
- ✅ Automatic IP assignment from pool
- ✅ Reuses IPs from deleted users
- ✅ Tracks allocation in database
- ✅ Prevents IP conflicts
- ✅ Supports 65,534 users per protocol

**How it works:**
1. When adding user: Checks for deleted user IPs first
2. If found: Reuses that IP
3. If not: Allocates next available IP
4. When deleting: Marks IP as "DELETED" for reuse

**IP Database:**
```
# /etc/mvpn/config/openvpn-ips.db
10.8.0.2 john ACTIVE
10.8.0.3 DELETED DELETED    # Available for reuse
10.8.0.4 jane ACTIVE
```

## 📊 View Logs

All logs are centralized in `/var/log/mvpn/`:

```bash
# Installation log
tail -f /var/log/mvpn/setup.log

# User management log
tail -f /var/log/mvpn/user-management.log

# Protocol logs
tail -f /var/log/mvpn/openvpn.log
tail -f /var/log/mvpn/wireguard.log
tail -f /var/log/mvpn/squid-access.log
tail -f /var/log/mvpn/v2ray-access.log
```

## 📥 Get User Profiles

Profiles are organized by protocol:

```bash
# List all profiles
ls -la /etc/mvpn/profiles/

# OpenVPN
cat /etc/mvpn/profiles/openvpn/john.ovpn

# WireGuard
cat /etc/mvpn/profiles/wireguard/jane.conf

# Squid
cat /etc/mvpn/profiles/squid/alice.txt

# V2Ray
cat /etc/mvpn/profiles/v2ray/bob.txt
```

## 🔒 Security Features

### Client Isolation
Clients cannot communicate with each other:
```bash
iptables -A FORWARD -i tun0 -o tun0 -j DROP  # OpenVPN
iptables -A FORWARD -i wg0 -o wg0 -j DROP    # WireGuard
```

### Private Network Protection
Clients cannot access server's private networks:
```bash
iptables -A FORWARD -s 10.8.0.0/16 -d 192.168.0.0/16 -j DROP
iptables -A FORWARD -s 10.8.0.0/16 -d 172.16.0.0/12 -j DROP
iptables -A FORWARD -s 10.8.0.0/16 -d 10.0.0.0/8 ! -d 10.8.0.0/16 -j DROP
```

### fail2ban Protection
- SSH: 3 attempts → 2-hour ban
- OpenVPN: 5 attempts → 1-hour ban
- Squid: 5 attempts → 1-hour ban
- Nginx/V2Ray: 5 attempts → 1-hour ban

### Encryption Standards

**OpenVPN:**
- Cipher: AES-256-GCM
- Auth: SHA256
- TLS: 1.3
- Key: 4096-bit RSA

**WireGuard:**
- Cipher: ChaCha20-Poly1305
- Key Exchange: Curve25519
- Preshared Keys: Quantum-resistant

**V2Ray:**
- TLS: 1.3
- Transport: WebSocket
- Protocols: VMess, VLESS

## 🛠️ Service Management

```bash
# Check status
systemctl status openvpn@server
systemctl status wg-quick@wg0
systemctl status squid
systemctl status xray

# Restart services
systemctl restart openvpn@server
systemctl restart wg-quick@wg0
systemctl restart squid
systemctl restart xray
```

## 🔄 Non-Interactive Installation

All scripts support non-interactive installation for remote deployment:

### Environment Variables

```bash
# V2Ray requires domain
export DOMAIN="vpn.aqibs.dev"
export EMAIL="admin@aqibs.dev"

# Run installation
./install-v2ray.sh
```

### Automated Deployment

```bash
# Install all protocols non-interactively
./setup.sh <<EOF
1
EOF

# Or specific protocol
./setup.sh <<EOF
2
EOF
```

### Remote Installation

```bash
# SSH to server and install
ssh root@server "curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/setup.sh | bash -s -- <<< '1'"
```

## 📈 Capacity Planning

### Small Deployment (< 1,000 users)
- Server: 2 CPU, 4GB RAM
- Protocols: OpenVPN + WireGuard
- Cost: ~$20/month

### Medium Deployment (1,000-10,000 users)
- Server: 4 CPU, 8GB RAM
- Protocols: All protocols
- Cost: ~$40/month

### Large Deployment (10,000-50,000 users)
- Server: 8 CPU, 16GB RAM
- Multiple servers recommended
- Load balancer
- Cost: ~$100/month per server

## 🔧 Troubleshooting

### Check User Count

```bash
# OpenVPN
grep "ACTIVE" /etc/mvpn/config/openvpn-ips.db | wc -l

# WireGuard
grep "ACTIVE" /etc/mvpn/config/wireguard-ips.db | wc -l

# Squid
wc -l < /etc/squid/passwords

# V2Ray
jq '.inbounds[0].settings.clients | length' /usr/local/etc/xray/config.json
```

### Check Available IPs

```bash
# OpenVPN
grep "DELETED" /etc/mvpn/config/openvpn-ips.db | wc -l

# WireGuard
grep "DELETED" /etc/mvpn/config/wireguard-ips.db | wc -l
```

### View User Management Log

```bash
tail -f /var/log/mvpn/user-management.log
```

## 📝 License

Proprietary software for Mecta VPN.

## 🤝 Support

Email: admin@aqibs.dev

---

**Version**: 1.0.0  
**Last Updated**: 2025-11-29  
**Capacity**: 65,534 users per protocol
