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

### 1. Backend Server (Generator)

Prerequisites:
- Cloudflare API Token in `/etc/environment` (`CF_Token`, `CF_Email`).
- `certbot` and `python3-certbot-dns-cloudflare` installed.

Run:
```bash
./generate-certs.sh
```

Follow the output instructions to push the keys to your repo.

### 2. VPN Nodes (Clients)

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
