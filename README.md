# MVPN - Complete VPN Infrastructure System

**Build your own enterprise-grade VPN infrastructure with master server management and automated node provisioning.**

[![License](https://img.shields.io/badge/license-Proprietary-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-Active-success.svg)]()

---

## 📋 What is MVPN?

MVPN is a **complete VPN infrastructure system** that enables you to deploy and manage your own VPN network with:

- **Master Server**: Centralized certificate management, API backend, and monitoring
- **VPN Nodes**: Automated deployment with multiple protocols (OpenVPN, WireGuard, Squid, V2Ray)
- **Monitoring**: Real-time heartbeat and metrics from all VPN servers
- **White-Label Ready**: Fully customizable with `.env` configuration

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   MASTER SERVER                             │
│  • Certificate Management (Let's Encrypt + Cloudflare)      │
│  • Backend API (srvlist)                                    │
│  • Monitoring Dashboard                                     │
│  • Auto-sync certs to VPNs(mvpn-scripts)                    │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Git Push (certs)
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                   VPN NODES (Multiple)                      │
│  • OpenVPN, WireGuard, Squid, V2Ray                         │
│  • Monitoring Agent (heartbeat to master)                   │
│  • Auto-update certificates                                 │
│  • User management per protocol                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Repositories

| Repository | Visibility | Purpose |
|------------|------------|---------|
| **[mvpn](https://github.com/aqibshahzad4485/mvpn)** | PUBLIC | Master documentation + deployment scripts |
| **[mvpn-backend](https://github.com/aqibshahzad4485/mvpn-backend)** | PRIVATE | Backend API + certificate management |
| **[mvpn-scripts](https://github.com/aqibshahzad4485/mvpn-scripts)** | PRIVATE | VPN installation scripts + SSL keys |
| **[mvpn-apps](https://github.com/aqibshahzad4485/mvpn-apps)** | PRIVATE | Client applications *(coming soon)* |

---

## 🚀 Quick Start

### Prerequisites

- Ubuntu 20.04/22.04 LTS servers(Master + Nodes)
- Domain name (e.g., `yourdomain.com`)
- Cloudflare account (for DNS + SSL)
- GitHub account with private repositories

### 1. Setup Master Server

**Recommended: Using .env file**

```bash
# Clone the repository
git clone https://github.com/aqibshahzad4485/mvpn.git
cd mvpn

# Copy and configure .env file
cp .env.example .env
nano .env  # Fill in GITHUB_TOKEN and CF_TOKEN

# Run setup
sudo bash master.sh
```

**Alternative: One-liner with environment variables**

```bash
GITHUB_TOKEN="yourtoken" \
CF_TOKEN="yourcftoken" \
bash <(curl -fsSL https://raw.githubusercontent.com/aqibshahzad4485/mvpn/main/master.sh)
```

**What it does**:
- Clones `mvpn-backend` and `mvpn-scripts` to `/opt/git/`
- Generates SSL certificates using Let's Encrypt + Cloudflare DNS
- Syncs certificates to `mvpn-scripts/keys/`
- Sets up srvlist API backend
- Configures automatic certificate renewal

### 2. Deploy VPN Nodes

**Recommended: Using .env file**

```bash
# Clone the repository
git clone https://github.com/aqibshahzad4485/mvpn.git
cd mvpn

# Copy and configure .env file
cp .env.example .env
nano .env  # Fill in GITHUB_TOKEN and optionally MASTER_API_URL/TOKEN

# Run setup
sudo bash vpn.sh
```

The script will:
1. Clone `mvpn-scripts` to `/opt/git/mvpn-scripts`
2. Prompt you to select which protocols to install
3. Prompt for domain (if installing V2Ray)
4. Install selected VPN protocols
5. Set up monitoring agent (if master API configured)

**Alternative: One-liner with environment variables**

```bash
GITHUB_TOKEN=ghp_your_readonly_token \
MASTER_API_URL=https://api.yourdomain.com \
MASTER_API_TOKEN=your_api_token \
INSTALL_TYPE=1 \
DOMAIN=vpn.example.com \
bash <(curl -fsSL https://raw.githubusercontent.com/aqibshahzad4485/mvpn/main/vpn.sh)
```

---

## 📖 Complete Setup Guide

### Step 1: Domain & Cloudflare Setup

1. **Purchase Domain**: Get a domain from any registrar
2. **Add to Cloudflare**:
   - Sign up at [cloudflare.com](https://cloudflare.com)
   - Add your domain
   - Update nameservers at your registrar
3. **Create API Token**:
   - Go to: Profile → API Tokens → Create Token
   - Use template: "Edit zone DNS"
   - Select your domain
   - Copy the token

### Step 2: GitHub Setup

1. **Create Private Repositories**:
   ```
   mvpn-backend  (private)
   mvpn-scripts  (private)
   ```

2. **Create GitHub Tokens**:
   
   **Master Server Token** (read/write):
   - Settings → Developer settings → Personal access tokens → Fine-grained tokens
   - Repository access: `mvpn-backend`, `mvpn-scripts`
   - Permissions: Contents (Read and write)
   
   **VPN Node Token** (read-only):
   - Repository access: `mvpn-scripts`
   - Permissions: Contents (Read-only)

### Step 3: Configure Environment

**For Master Server:**

```bash
cd mvpn
cp .env.example .env
nano .env
```

Fill in the required values:

```bash
# REQUIRED
GITHUB_TOKEN="ghp_your_token_here"
CF_TOKEN="your_cloudflare_token"

# Optional - Update if needed
CF_EMAIL="your@email.com"
VPN_DOMAIN="vpn.yourdomain.com"
GITHUB_ORG="your-github-username"
```

**For VPN Servers:**

```bash
cd mvpn
cp .env.example .env
nano .env
```

Fill in the required values:

```bash
# REQUIRED
GITHUB_TOKEN="ghp_readonly_token"

# Optional - For monitoring
MASTER_API_URL="https://api.yourdomain.com"
MASTER_API_TOKEN="your_api_token"

# Optional - For automated setup
INSTALL_TYPE="1"  # 1=All, 2=OpenVPN, 3=WireGuard, 4=Squid, 5=V2Ray
DOMAIN="vpn1.yourdomain.com"  # Required if installing V2Ray
```

### Step 4: Deploy Master Server

```bash
# SSH into your master server
ssh root@master-server-ip

# Clone and configure
git clone https://github.com/aqibshahzad4485/mvpn.git
cd mvpn
cp .env.example .env
nano .env  # Fill in GITHUB_TOKEN and CF_TOKEN

# Run setup
sudo bash master.sh

# Verify installation
systemctl status mvpn-api
ls -la /opt/git/mvpn-backend
ls -la /opt/git/mvpn-scripts/keys
```

### Step 5: Deploy VPN Nodes

```bash
# SSH into your VPN server
ssh root@vpn-server-ip

# Clone and configure
git clone https://github.com/aqibshahzad4485/mvpn.git
cd mvpn
cp .env.example .env
nano .env  # Fill in GITHUB_TOKEN and optional settings

# Run setup (will prompt for installation type and domain if needed)
sudo bash vpn.sh

# Verify installation
systemctl status openvpn@server
systemctl status wg-quick@wg0
systemctl status squid
systemctl status xray
systemctl status vpn-monitor
```

---

## 🔐 Certificate Management

### Automatic Workflow

1. **Master Server** generates certificates using Let's Encrypt + Cloudflare DNS
2. **Sync Script** copies certificates to `mvpn-scripts/keys/`
3. **Git Push** updates the mvpn-scripts repository
4. **VPN Nodes** pull updates every 2 months (via cron)

### Manual Certificate Update

**On Master Server**:
```bash
cd /opt/git/mvpn-backend
./scripts/certs/generate-certs.sh  # Generate/renew
./scripts/certs/sync-certs.sh      # Sync to mvpn-scripts
```

**On VPN Nodes**:
```bash
/opt/git/mvpn-scripts/update-certs.sh
```

### Automatic Updates (Cron)

VPN nodes automatically check for certificate updates every 2 months:
```bash
# Cron job (added by setup.sh)
0 3 1 */2 * /opt/git/mvpn-scripts/update-certs.sh
```

---

## 📊 Monitoring & Management

### Agent System

Each VPN node runs a monitoring agent that:
- Sends heartbeat every 60 seconds
- Reports server metrics (CPU, RAM, bandwidth)
- Tracks active VPN connections
- Logs to master server API

### Master Server API

**Endpoints**:
- `GET /api/servers` - List all VPN servers
- `GET /api/servers/:id/status` - Server status
- `GET /api/servers/:id/users` - User list
- `POST /api/servers/:id/users` - Add user
- `DELETE /api/servers/:id/users/:userId` - Remove user
- `GET /api/certs/status` - Certificate expiry status

**Authentication**: Bearer token in `Authorization` header

---

## 🛠️ VPN Protocols

| Protocol | Port | Use Case | Features |
|----------|------|----------|----------|
| **OpenVPN** | 1194/UDP | Universal compatibility | AES-256-GCM, TLS 1.3 |
| **WireGuard** | 51820/UDP | Modern, fast VPN | ChaCha20, QR codes |
| **Squid** | 3128/TCP | HTTP/HTTPS proxy | Authentication, bandwidth limiting |
| **V2Ray/Xray** | 443/TCP | Censorship circumvention | VMess, VLESS, WebSocket + TLS |

### User Management

```bash
# Add users (on VPN server)
/usr/local/bin/mvpn/scripts/mgmt/add-openvpn-user.sh username
/usr/local/bin/mvpn/scripts/mgmt/add-wireguard-user.sh username
/usr/local/bin/mvpn/scripts/mgmt/add-squid-user.sh username
/usr/local/bin/mvpn/scripts/mgmt/add-v2ray-user.sh username

# Delete users
/usr/local/bin/mvpn/scripts/mgmt/delete-openvpn-user.sh username
```

---

## 🎨 Customization & White-Labeling

All branding and configuration is controlled via `.env` files:

```bash
# Your company branding
COMPANY_NAME="Your VPN"
COMPANY_DOMAIN="yourdomain.com"
COMPANY_EMAIL="support@yourdomain.com"

# VPN domain
VPN_DOMAIN="vpn.yourdomain.com"

# Email templates
WELCOME_EMAIL_TEMPLATE="/path/to/template.html"
```

Update `.env` files in all repositories and redeploy.

---

## 🔧 Troubleshooting

### Master Server Issues

```bash
# Check API status
systemctl status mvpn-api
journalctl -u mvpn-api -n 50

# Check certificate generation
/opt/git/mvpn-backend/scripts/certs/check-certs.sh

# View sync logs
tail -f /var/log/mvpn/cert-sync.log
```

### VPN Node Issues

```bash
# Check services
systemctl status openvpn@server wg-quick@wg0 squid xray

# Check agent
systemctl status vpn-monitor
journalctl -u vpn-monitor -n 50

# Update certificates
/opt/git/mvpn-scripts/update-certs.sh

# View logs
tail -f /var/log/mvpn/setup.log
tail -f /var/log/mvpn/user-management.log
```

### Common Issues

**Certificate not syncing**:
```bash
# On master server
cd /opt/git/mvpn-scripts
git status  # Check for uncommitted changes
git pull    # Ensure up to date
```

**Agent not reporting**:
```bash
# Check API token
cat /opt/git/mvpn-scripts/.env | grep MASTER_API_TOKEN

# Test API connection
curl -H "Authorization: Bearer $MASTER_API_TOKEN" \
  $MASTER_API_URL/api/servers
```

---

## 🚧 Future Development

### mvpn-apps (Coming Soon)

Client applications for end users:

- **Android** - Native Android app
- **iOS** - Native iOS app  
- **macOS** - Native macOS app
- **Windows** - Native Windows app
- **Browser Extensions** - Chrome, Firefox, Edge

**Status**: Planning phase. Will be developed after completing API and management features.

---

## 📝 Documentation

- **[mvpn-backend README](https://github.com/aqibshahzad4485/mvpn-backend)** - Backend API documentation
- **[mvpn-scripts README](https://github.com/aqibshahzad4485/mvpn-scripts)** - VPN installation guide
- **[srvlist API](https://github.com/aqibshahzad4485/mvpn-backend/tree/main/srvlist)** - API reference

---

## 🔒 Security Best Practices

1. **GitHub Tokens**:
   - Use fine-grained tokens with minimal permissions
   - Rotate tokens every 90 days
   - Never commit tokens to repositories

2. **Certificates**:
   - Keep `mvpn-scripts` repository private
   - Set `privkey.pem` permissions to `600`
   - Monitor expiry dates

3. **API Security**:
   - Use strong API tokens
   - Enable rate limiting
   - Monitor access logs

4. **Server Hardening**:
   - Enable UFW firewall
   - Configure fail2ban
   - Disable password authentication
   - Keep systems updated

---

## 📄 License

Proprietary software for Mecta VPN.

---

## 🤝 Support

- **Email**: admin@aqibs.dev
- **Documentation**: This README + repository READMEs
- **Issues**: GitHub Issues in respective repositories

---

**Version**: 1.0.0  
**Last Updated**: 2025-12-06  
**Maintained by**: Mecta VPN Team
