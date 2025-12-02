# Mecta VPN - Enterprise VPN Solution

Production-ready VPN server with OpenVPN, WireGuard, Squid, and V2Ray/Xray.

## 🔐 Certificate Management

Mecta VPN uses a centralized certificate management system to handle SSL for V2Ray and Squid.

### Workflow
1.  **Generate**: Run `scripts/certs/generate-certs.sh` on your backend server.
    *   It checks for existing Let's Encrypt certs.
    *   Copies them to `scripts/certs/keys/`.
    *   Displays expiry date.
2.  **Push**: Commit and push the `scripts/certs/keys/` directory to your repository.
3.  **Deploy**: On VPN servers, pull the repository and run the installation scripts.
    *   `install-v2ray.sh` and `install-squid.sh` automatically detect certs in `scripts/certs/keys/`.
    *   They copy them to `/etc/mvpn/config/certs/key/` for use.

### Usage
```bash
# On Backend
./scripts/certs/generate-certs.sh
git add scripts/certs/keys
git commit -m "Update certs"
git push

# On VPN Server
cd /tmp/mvpn
git pull
./scripts/setup.sh 1
```

## 🚀 Quick Start

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/aqibshahzad4485/mvpn/main/scripts/setup.sh | sudo bash
```

### Manual Installation

```bash
git clone https://github.com/aqibshahzad4485/mvpn.git /tmp/mvpn
cd /tmp/mvpn
sudo ./scripts/setup.sh
```

## 🛠 Features

- **OpenVPN**: AES-256-GCM, TLS 1.3, Client Isolation
- **WireGuard**: ChaCha20, QR Codes, High Performance
- **Squid Proxy**: HTTP/HTTPS Authentication, Bandwidth Limiting
- **V2Ray/Xray**: VMess/VLESS, WebSocket + TLS, CDN Support
- **Security**: UFW Firewall, Fail2Ban, Server Hardening
- **Automation**: Non-interactive installation support

## 📚 Documentation

- [Automation Guide](AUTOMATION.md)
- [Script Details](scripts/README.md)
- [Certificate Management](scripts/certs/README.md)

## 📝 License

Proprietary software for Mecta VPN.

## 🤝 Support

For support, email: admin@aqibs.dev
