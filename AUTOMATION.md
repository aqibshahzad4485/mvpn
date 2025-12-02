# Automated & Remote Deployment Guide

## 🚀 Non-Interactive Installation

You can now install the entire VPN stack remotely without any user interaction.

### 1. Basic Usage (Install All)

```bash
# Using arguments (1 = Install All)
./setup.sh 1

# Using environment variable
INSTALL_TYPE=1 ./setup.sh
```

### 2. Protocol Selection Codes

| Code | Action |
|------|--------|
| `1` | Install All (OpenVPN + WireGuard + Squid + V2Ray) |
| `2` | OpenVPN Only |
| `3` | WireGuard Only |
| `4` | Squid Proxy Only |
| `5` | V2Ray Only |
| `7` | Server Hardening Only |

### 3. V2Ray Automation (Requires Domain)

V2Ray requires a domain for SSL. Pass it via the `DOMAIN` environment variable:

```bash
# Install V2Ray with domain
export DOMAIN="vpn.aqibs.dev"
./setup.sh 5
```

### 4. Full Remote Deployment Example

Run this single command on your local machine to deploy to a remote server:

```bash
# Deploy to srv1
ssh root@srv1.example.com "curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/setup.sh > setup.sh && chmod +x setup.sh && DOMAIN=srv1.example.com ./setup.sh 1"
```

---

## 🌐 Domain Strategy for Multiple Servers

Since V2Ray requires a valid SSL certificate, you cannot use an IP address.

### Recommended Strategy: Subdomains

Assign a unique subdomain to each server.

**DNS Records:**
- `srv1.aqibs.dev` -> `1.2.3.4` (Server 1 IP)
- `srv2.aqibs.dev` -> `5.6.7.8` (Server 2 IP)

**Deployment:**

**Server 1:**
```bash
export DOMAIN="srv1.aqibs.dev"
./setup.sh 1
```

**Server 2:**
```bash
export DOMAIN="srv2.aqibs.dev"
./setup.sh 1
```

### Why not Wildcards (*.aqibs.dev)?

Wildcard certificates (`*.aqibs.dev`) require **DNS Validation**, which means the script needs API access to your DNS provider (Cloudflare, AWS Route53, etc.) to prove ownership.

**Current Script uses HTTP Validation:**
- Easier to automate (no API keys needed)
- Works for any server with port 80 open
- Generates a unique cert for `srv1.aqibs.dev` automatically

---

## 🔧 Troubleshooting Automation

### Check Logs
```bash
tail -f /var/log/mvpn/setup/install-*.log
```

### Verify V2Ray SSL
If SSL fails, ensure:
1. Domain points to server IP (`ping srv1.aqibs.dev`)
2. Port 80 is open (Script now handles this automatically)
3. No other service is using port 80 (e.g., Apache)

### Force Non-Interactive
The script automatically detects non-interactive mode when arguments are passed. You can also force it:
```bash
export NON_INTERACTIVE=true
./setup.sh 1
```
