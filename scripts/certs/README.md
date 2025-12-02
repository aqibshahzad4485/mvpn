# Centralized SSL Certificate Management

This directory contains scripts for managing wildcard SSL certificates (`*.vpn.aqibs.dev`).

## 🏗️ Workflow

1.  **Generate**: Run `generate-certs.sh` on your backend server.
    *   Checks for existing Let's Encrypt certs in `/etc/letsencrypt/live/`.
    *   Copies them to `./keys/` directory.
    *   Checks expiry date.
2.  **Push**: Commit the `./keys/` directory to your private repository.
3.  **Deploy**: On VPN nodes, `install-v2ray.sh` and `install-squid.sh` will:
    *   Detect certs in `scripts/certs/keys/`.
    *   Copy them to `/etc/mvpn/config/certs/key/`.
    *   Configure services to use them.

## 🛠️ Setup Guide

### 1. Create Cloudflare API Token

1. **Login to Cloudflare Dashboard**: https://dash.cloudflare.com/
2. **Navigate to API Tokens**:
   - Click on your profile icon (top right)
   - Select **"My Profile"**
   - Go to **"API Tokens"** tab
   - Click **"Create Token"**

3. **Configure Token Permissions**:
   - **Option A - Use Template**:
     - Select **"Edit zone DNS"** template
     - Click **"Use template"**
   
   - **Option B - Custom Token**:
     - Token name: `Mecta VPN Cert Manager`
     - Permissions:
       - **Zone** → **DNS** → **Edit**
       - **Zone** → **Zone** → **Read**
     - Zone Resources:
       - **Include** → **Specific zone** → Select your domain (e.g., `aqibs.dev`)
     - TTL: Leave blank (no expiration) or set as needed

4. **Create and Copy Token**:
   - Click **"Continue to summary"**
   - Click **"Create Token"**
   - **IMPORTANT**: Copy the token immediately (you won't see it again!)

### 2. Configure Backend Server

1. **Install Dependencies**:
```bash
apt update
apt install certbot python3-certbot-dns-cloudflare -y
```

2. **Set Environment Variables**:
```bash
# Edit /etc/environment
sudo nano /etc/environment

# Add these lines (replace with your actual values):
CF_Token="your_cloudflare_api_token_here"
CF_Email="your-email@example.com"

# Save and reload environment
source /etc/environment
```

**Example Configuration**:
```bash
# /etc/environment
CF_Token="AbCdEf123456_your_actual_token_here_XyZ789"
CF_Email="admin@aqibs.dev"
DOMAIN="vpn.aqibs.dev"
```

3. **Run Certificate Generator**:
```bash
cd /path/to/mvpn
./scripts/certs/generate-certs.sh
```

Follow the output instructions to push the keys to your repo.

### 3. VPN Nodes (Clients)

Just pull the latest repo changes and run the setup script:

```bash
cd /tmp/mvpn
git pull
./scripts/setup.sh 1
```

## 🔐 Security Note

The `keys` directory contains your **Private Key** (`privkey.pem`).
**Ensure your repository is PRIVATE.**

## 📂 File Structure

```
scripts/certs/
├── generate-certs.sh   # Generator script
├── fetch-certs.sh      # (Deprecated) Fetcher script
├── keys/               # Stores active certificates
│   ├── fullchain.pem
│   └── privkey.pem
└── README.md
```
