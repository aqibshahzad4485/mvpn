# Phase 1: Protocol Installation Scripts - Implementation Guide

## 🎯 Overview

This phase provides production-ready installation scripts for:
- **OpenVPN** - Industry-standard VPN protocol
- **WireGuard** - Modern, fast VPN protocol
- **Squid** - HTTP/HTTPS proxy server
- **V2Ray/Xray** - Advanced proxy protocol

All scripts include **enterprise-grade security hardening**.

---

## 🔒 Security Architecture

### Network Isolation Strategy

Each VPN protocol operates in its own isolated network range to prevent cross-protocol access:

| Protocol | IP Range | Subnet | Max Clients |
|----------|----------|--------|-------------|
| OpenVPN | 10.8.0.0/24 | 255.255.255.0 | 254 |
| WireGuard | 10.9.0.0/24 | 255.255.255.0 | 254 |
| Squid | N/A (Proxy) | - | Unlimited |
| V2Ray | 10.10.0.0/24 | 255.255.255.0 | 254 |

### Security Principles

1. **Client Isolation**: Clients cannot communicate with each other
2. **Server Protection**: Clients cannot access server's private network
3. **Firewall Hardening**: Only necessary ports exposed
4. **Intrusion Prevention**: fail2ban monitoring all services
5. **Encryption**: Strong ciphers and key sizes
6. **Logging**: Comprehensive audit trails

---

## 📦 Installation Scripts

### Available Scripts

1. `scripts/install-openvpn.sh` - OpenVPN with TLS 1.3, AES-256-GCM
2. `scripts/install-wireguard.sh` - WireGuard with ChaCha20-Poly1305
3. `scripts/install-squid.sh` - Squid with SSL bump and authentication
4. `scripts/install-v2ray.sh` - V2Ray/Xray with VMess/VLESS
5. `scripts/install-all.sh` - Install all protocols at once
6. `scripts/harden-server.sh` - Server security hardening

### Prerequisites

- **OS**: Ubuntu 20.04/22.04 or Debian 11/12
- **RAM**: Minimum 2GB
- **Root Access**: Required
- **Clean Server**: Recommended (no conflicting services)

---

## 🚀 Quick Start

### Install Single Protocol

```bash
# Download and run
cd /root
git clone <your-repo>
cd mvpn/scripts

# Make executable
chmod +x *.sh

# Install specific protocol
./install-openvpn.sh
# or
./install-wireguard.sh
# or
./install-squid.sh
# or
./install-v2ray.sh
```

### Install All Protocols

```bash
./install-all.sh
```

### Harden Server (Recommended)

```bash
./harden-server.sh
```

---

## 🔐 Security Features

### Firewall (UFW + iptables)

- Default deny incoming
- Allow only VPN ports
- Client-to-client blocking
- Private network protection
- Rate limiting on SSH

### fail2ban

- SSH brute-force protection
- OpenVPN authentication monitoring
- Squid authentication monitoring
- Auto-ban after 5 failed attempts
- 1-hour ban duration

### System Hardening

- Disable root SSH login
- SSH key-only authentication
- Disable IPv6 (optional)
- Kernel parameter tuning
- Automatic security updates
- Disable unnecessary services

### Encryption Standards

**OpenVPN:**
- Cipher: AES-256-GCM
- Auth: SHA256
- TLS: TLS 1.3
- Key Size: 4096-bit RSA
- DH Params: 4096-bit

**WireGuard:**
- Cipher: ChaCha20-Poly1305
- Key Exchange: Curve25519
- Hashing: BLAKE2s
- Key Size: 256-bit

**V2Ray:**
- VMess: AES-128-GCM
- VLESS: None (TLS handles encryption)
- TLS: TLS 1.3
- Certificate: Let's Encrypt

---

## 📋 Post-Installation

### Verify Installation

```bash
# Check service status
systemctl status openvpn@server
systemctl status wg-quick@wg0
systemctl status squid
systemctl status xray

# Check firewall
ufw status verbose

# Check fail2ban
fail2ban-client status
```

### Get Client Configurations

**OpenVPN:**
```bash
cat /root/client.ovpn
```

**WireGuard:**
```bash
cat /root/wg0-client.conf
```

**Squid:**
```bash
cat /root/squid-credentials.txt
```

**V2Ray:**
```bash
cat /root/v2ray-link.txt
```

---

## 🔧 Configuration Files

### OpenVPN
- Server config: `/etc/openvpn/server.conf`
- Client config: `/root/client.ovpn`
- Logs: `/var/log/openvpn/`

### WireGuard
- Server config: `/etc/wireguard/wg0.conf`
- Client config: `/root/wg0-client.conf`
- Logs: `journalctl -u wg-quick@wg0`

### Squid
- Server config: `/etc/squid/squid.conf`
- Password file: `/etc/squid/passwords`
- Logs: `/var/log/squid/`

### V2Ray
- Server config: `/usr/local/etc/xray/config.json`
- Client link: `/root/v2ray-link.txt`
- Logs: `/var/log/xray/`

---

## 🛡️ Firewall Rules

### Default Rules (Applied by scripts)

```bash
# SSH (rate limited)
ufw limit 22/tcp

# OpenVPN
ufw allow 1194/udp

# WireGuard
ufw allow 51820/udp

# Squid
ufw allow 3128/tcp

# V2Ray (with TLS)
ufw allow 443/tcp

# Enable firewall
ufw enable
```

### Client Isolation (iptables)

```bash
# Block client-to-client communication
iptables -A FORWARD -i tun0 -o tun0 -j DROP
iptables -A FORWARD -i wg0 -o wg0 -j DROP

# Block access to private networks
iptables -A FORWARD -s 10.8.0.0/24 -d 192.168.0.0/16 -j DROP
iptables -A FORWARD -s 10.8.0.0/24 -d 172.16.0.0/12 -j DROP
iptables -A FORWARD -s 10.8.0.0/24 -d 10.0.0.0/8 -j DROP
```

---

## 📊 Monitoring

### Check Connected Clients

**OpenVPN:**
```bash
cat /var/log/openvpn/status.log
```

**WireGuard:**
```bash
wg show
```

**Squid:**
```bash
tail -f /var/log/squid/access.log
```

**V2Ray:**
```bash
journalctl -u xray -f
```

### Check Bandwidth Usage

```bash
# Install vnstat
apt install vnstat -y

# Check usage
vnstat -l
```

---

## 🔄 Updates & Maintenance

### Update Protocols

```bash
# OpenVPN
apt update && apt upgrade openvpn -y

# WireGuard
apt update && apt upgrade wireguard -y

# Squid
apt update && apt upgrade squid -y

# V2Ray (reinstall script)
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

### Backup Configurations

```bash
# Create backup
tar -czf vpn-backup-$(date +%Y%m%d).tar.gz \
  /etc/openvpn \
  /etc/wireguard \
  /etc/squid \
  /usr/local/etc/xray \
  /root/*.ovpn \
  /root/*.conf \
  /root/*.txt

# Download backup
scp root@server:/root/vpn-backup-*.tar.gz ./
```

---

## ⚠️ Troubleshooting

### OpenVPN Not Starting

```bash
# Check logs
journalctl -u openvpn@server -n 50

# Test config
openvpn --config /etc/openvpn/server.conf --verb 3
```

### WireGuard Connection Issues

```bash
# Check interface
ip a show wg0

# Check routing
ip route show

# Restart
systemctl restart wg-quick@wg0
```

### Squid Authentication Failing

```bash
# Recreate password
htpasswd -c /etc/squid/passwords username

# Restart squid
systemctl restart squid
```

### V2Ray Not Accessible

```bash
# Check if running
systemctl status xray

# Check port
netstat -tulpn | grep 443

# Check certificate
certbot certificates
```

---

## 📝 Next Steps

After completing Phase 1:

1. ✅ Test each protocol with a client
2. ✅ Verify client isolation
3. ✅ Check firewall rules
4. ✅ Monitor logs for errors
5. ✅ Backup all configurations
6. 🔜 Proceed to Phase 2 (Enhanced Agent)

---

**Security Note**: These scripts are designed for production use with security best practices. Always review scripts before running on production servers.
