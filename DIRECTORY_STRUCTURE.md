# Directory Structure Update - Implementation Guide

## 📁 New Directory Structure

```
/usr/local/bin/mvpn/          # Main installation directory
├── scripts/                   # Installation scripts
│   ├── install-openvpn.sh
│   ├── install-wireguard.sh
│   ├── install-squid.sh
│   ├── install-v2ray.sh
│   ├── install-all.sh
│   ├── harden-server.sh
│   ├── add-openvpn-user.sh
│   ├── add-wireguard-user.sh
│   ├── add-squid-user.sh
│   └── add-v2ray-user.sh
├── bin/                       # Utility binaries
└── lib/                       # Common libraries
    └── common.sh

/etc/mvpn/                     # Configuration directory
├── profiles/                  # User profiles
│   ├── openvpn/              # OpenVPN profiles
│   │   ├── client1.ovpn
│   │   └── client2.ovpn
│   ├── wireguard/            # WireGuard profiles
│   │   ├── client1.conf
│   │   └── client2.conf
│   ├── squid/                # Squid credentials
│   │   └── credentials.txt
│   └── v2ray/                # V2Ray links
│       ├── client1.txt
│       └── client2.txt
└── config/                    # Server configurations
    └── install-info.json

/var/log/mvpn/                 # Centralized logging
├── setup/                     # Installation logs
│   ├── install-YYYYMMDD-HHMMSS.log
│   ├── openvpn-install.log
│   ├── wireguard-install.log
│   ├── squid-install.log
│   ├── v2ray-install.log
│   └── hardening.log
├── openvpn/                   # OpenVPN logs
│   ├── openvpn.log
│   └── status.log
├── wireguard/                 # WireGuard logs
│   └── wg0.log
├── squid/                     # Squid logs
│   ├── access.log
│   └── cache.log
├── v2ray/                     # V2Ray logs
│   ├── access.log
│   └── error.log
└── security/                  # Security logs
    ├── fail2ban.log
    └── ufw.log
```

## 🔄 Changes Required

### 1. Installation Scripts

All installation scripts need to be updated to:
- Create standardized directories
- Save profiles to `/etc/mvpn/profiles/{protocol}/`
- Log to `/var/log/mvpn/{protocol}/`
- Update service configurations to use new log paths

### 2. Profile Generation

**Old Locations:**
- OpenVPN: `/root/client.ovpn`
- WireGuard: `/root/wg0-client.conf`
- Squid: `/root/squid-credentials.txt`
- V2Ray: `/root/v2ray-links.txt`

**New Locations:**
- OpenVPN: `/etc/mvpn/profiles/openvpn/client.ovpn`
- WireGuard: `/etc/mvpn/profiles/wireguard/client.conf`
- Squid: `/etc/mvpn/profiles/squid/credentials.txt`
- V2Ray: `/etc/mvpn/profiles/v2ray/client.txt`

### 3. Service Configurations

**OpenVPN** (`/etc/openvpn/server.conf`):
```bash
# Old
log-append /var/log/openvpn/openvpn.log
status /var/log/openvpn/status.log

# New
log-append /var/log/mvpn/openvpn/openvpn.log
status /var/log/mvpn/openvpn/status.log
```

**Squid** (`/etc/squid/squid.conf`):
```bash
# Old
access_log /var/log/squid/access.log
cache_log /var/log/squid/cache.log

# New
access_log /var/log/mvpn/squid/access.log
cache_log /var/log/mvpn/squid/cache.log
```

**V2Ray** (`/usr/local/etc/xray/config.json`):
```json
// Old
"access": "/var/log/xray/access.log",
"error": "/var/log/xray/error.log"

// New
"access": "/var/log/mvpn/v2ray/access.log",
"error": "/var/log/mvpn/v2ray/error.log"
```

### 4. User Management Scripts

Create new scripts in `/usr/local/bin/mvpn/scripts/`:
- `add-openvpn-user.sh` - Generate `.ovpn` files
- `add-wireguard-user.sh` - Generate `.conf` files
- `add-squid-user.sh` - Generate credentials
- `add-v2ray-user.sh` - Generate links

### 5. Management Commands

Create wrapper commands in `/usr/local/bin/`:
- `mvpn-status` - Show server status
- `mvpn-add-user` - Add new user
- `mvpn-list-users` - List all users
- `mvpn-delete-user` - Delete user
- `mvpn-logs` - View logs

## 📝 Updated Installation Process

### One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/setup.sh | sudo bash
```

### Manual Install

```bash
# Clone repository
git clone YOUR_REPO /tmp/mvpn
cd /tmp/mvpn

# Run setup
sudo ./setup.sh
```

### What setup.sh Does

1. Creates directory structure
2. Copies scripts to `/usr/local/bin/mvpn/`
3. Interactive protocol selection
4. Installs selected protocols
5. Configures logging
6. Hardens server
7. Creates management commands
8. Saves installation info

## 🎯 Usage After Installation

### Check Status
```bash
mvpn-status
```

### Add User
```bash
mvpn-add-user
# Interactive menu to select protocol and enter username
```

### List Users
```bash
mvpn-list-users
```

### View Logs
```bash
# All logs
ls -la /var/log/mvpn/

# Specific protocol
tail -f /var/log/mvpn/openvpn/openvpn.log
tail -f /var/log/mvpn/wireguard/wg0.log
tail -f /var/log/mvpn/squid/access.log
tail -f /var/log/mvpn/v2ray/access.log

# Setup logs
cat /var/log/mvpn/setup/install-*.log
```

### Get User Profiles
```bash
# List all profiles
ls -la /etc/mvpn/profiles/

# Get specific profile
cat /etc/mvpn/profiles/openvpn/client.ovpn
cat /etc/mvpn/profiles/wireguard/client.conf
cat /etc/mvpn/profiles/squid/credentials.txt
cat /etc/mvpn/profiles/v2ray/client.txt
```

## 🔧 Migration from Old Structure

If you have existing installations:

```bash
# Backup old profiles
mkdir -p /tmp/mvpn-backup
cp /root/*.ovpn /tmp/mvpn-backup/ 2>/dev/null
cp /root/*.conf /tmp/mvpn-backup/ 2>/dev/null
cp /root/*.txt /tmp/mvpn-backup/ 2>/dev/null

# Run new setup
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/setup.sh | sudo bash

# Move old profiles to new location
mv /tmp/mvpn-backup/*.ovpn /etc/mvpn/profiles/openvpn/ 2>/dev/null
mv /tmp/mvpn-backup/*.conf /etc/mvpn/profiles/wireguard/ 2>/dev/null
```

## ✅ Benefits

1. **Organized**: All MVPN files in standard locations
2. **Centralized Logging**: All logs in one place
3. **Easy Management**: Simple commands for common tasks
4. **Professional**: Follows Linux FHS standards
5. **Scalable**: Easy to add more protocols
6. **Maintainable**: Clear separation of concerns

## 📋 Next Steps

1. Update all installation scripts with new paths
2. Create user management scripts
3. Update README with new structure
4. Test installation on clean server
5. Create migration guide for existing installations
