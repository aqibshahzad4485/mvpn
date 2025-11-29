# MVPN - Multi-Protocol VPN Server

Production-ready VPN server with OpenVPN, WireGuard, Squid, and V2Ray/Xray.

## 🚀 Quick Start

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/setup.sh | sudo bash
```

### Manual Installation

```bash
git clone YOUR_REPO /tmp/mvpn
cd /tmp/mvpn
sudo ./setup.sh
```

## 📁 Directory Structure

```
/usr/local/bin/mvpn/          # Installation directory
├── scripts/                   # Installation & management scripts
├── bin/                       # Utility binaries
└── lib/                       # Common libraries

/etc/mvpn/                     # Configuration
├── profiles/                  # User profiles
│   ├── openvpn/              # .ovpn files
│   ├── wireguard/            # .conf files
│   ├── squid/                # credentials
│   └── v2ray/                # links
└── config/                    # Server config

/var/log/mvpn/                 # Centralized logging
├── setup/                     # Installation logs
├── openvpn/                   # OpenVPN logs
├── wireguard/                 # WireGuard logs
├── squid/                     # Squid logs
├── v2ray/                     # V2Ray logs
└── security/                  # Security logs
```

## 🔐 Protocols

| Protocol | Port | IP Range | Use Case |
|----------|------|----------|----------|
| OpenVPN | 1194/UDP | 10.8.0.0/24 | Universal compatibility |
| WireGuard | 51820/UDP | 10.9.0.0/24 | Modern, fast VPN |
| Squid | 3128/TCP | N/A | HTTP/HTTPS proxy |
| V2Ray | 443/TCP | 10.10.0.0/24 | Censorship circumvention |

## 🎯 Management Commands

```bash
# Check server status
mvpn-status

# Add new user
mvpn-add-user

# List all users
mvpn-list-users

# Delete user
mvpn-delete-user
```

## 📊 View Logs

```bash
# All logs
ls -la /var/log/mvpn/

# Specific protocol
tail -f /var/log/mvpn/openvpn/openvpn.log
tail -f /var/log/mvpn/wireguard/wg0.log
tail -f /var/log/mvpn/squid/access.log
tail -f /var/log/mvpn/v2ray/access.log
```

## 📥 Get User Profiles

```bash
# OpenVPN
cat /etc/mvpn/profiles/openvpn/client.ovpn

# WireGuard
cat /etc/mvpn/profiles/wireguard/client.conf

# Squid
cat /etc/mvpn/profiles/squid/credentials.txt

# V2Ray
cat /etc/mvpn/profiles/v2ray/client.txt
```

## 🔒 Security Features

- ✅ Client isolation (clients can't communicate)
- ✅ Private network protection
- ✅ fail2ban on all services
- ✅ Firewall hardening (UFW + iptables)
- ✅ Automatic security updates
- ✅ Enterprise-grade encryption

## 📖 Documentation

- [Installation Guide](PHASE1_IMPLEMENTATION.md)
- [Directory Structure](DIRECTORY_STRUCTURE.md)
- [Implementation Plan](IMPLEMENTATION_PLAN.md)
- [Scripts README](scripts/README.md)

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

## 📝 License

Proprietary software for Mect VPN.

## 🤝 Support

Email: admin@aqibs.dev

---

**Version**: 1.0.0  
**Last Updated**: 2025-11-29
