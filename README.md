# Mect VPN Monitor System

A comprehensive VPN server monitoring system with real-time heartbeat tracking, load monitoring, and web-based dashboard management.

## 🏗️ Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Agent     │───────▶│    API      │────────▶│  Dashboard  │
│  (Monitor)  │  HTTP   │  (FastAPI)  │  REST   │   (Vue.js)  │
└─────────────┘         └─────────────┘         └─────────────┘
                               │
                        ┌──────┴─────┐
                        │            │
                   ┌────▼────┐   ┌───▼────┐
                   │ MongoDB │   │ Redis  │
                   │(Persist)│   │(Cache) │
                   └─────────┘   └────────┘
```

## 📋 Features

### Agent (Monitor)
- ✅ Real-time CPU, RAM, and Network monitoring
- ✅ Service status tracking (WireGuard, OpenVPN, Squid, X-UI/V2Ray)
- ✅ Automatic IP geolocation with ISO country codes
- ✅ Configurable heartbeat intervals (default: 2 minutes)
- ✅ Systemd service integration

### API (Backend)
- ✅ FastAPI-based REST API
- ✅ JWT authentication with role-based access control (readonly, admin, superadmin)
- ✅ MongoDB for persistent storage
- ✅ Redis for caching and performance
- ✅ Automatic server status monitoring
- ✅ User management endpoints
- ✅ Password change and reset functionality

### Dashboard (Frontend)
- ✅ Modern Vue.js 3 single-page application
- ✅ Real-time server status updates
- ✅ Server configuration management (gaming, streaming, paid flags)
- ✅ User authentication and management
- ✅ Beautiful glassmorphic UI with Tailwind CSS
- ✅ ISO country code display

## 🚀 Quick Start

### Prerequisites

- **API Server:**
  - Python 3.8+
  - MongoDB
  - Redis
  - Docker & Docker Compose (recommended)

- **Agent Servers:**
  - Python 3.8+
  - Linux with systemd
  - Internet connectivity

### 1. API Server Setup (Docker Compose)

```bash
# Clone or download the project
cd /path/to/project

# Create environment file
cat > .env << EOF
MONGO_URL=mongodb://mongo:27017
REDIS_URL=redis://redis:6379
SECRET_KEY=$(openssl rand -hex 32)
AGENT_API_KEY=$(openssl rand -hex 32)
EOF

# Start services
docker-compose up -d

# Check logs
docker-compose logs -f api
```

The API will be available at `http://localhost:8000`  
Dashboard will be available at `http://localhost:8000/dashboard/`

**Default credentials:**
- Username: `admin`
- Password: `admin`

⚠️ **IMPORTANT:** Change the default password immediately after first login!

### 2. Agent Setup (VPN Servers)

On each VPN server you want to monitor:

```bash
# Install Python dependencies
pip3 install requests

# Create agent directory
sudo mkdir -p /usr/local/bin/agent
cd /usr/local/bin/agent

# Copy monitor script
sudo cp /path/to/agent/monitor.py /usr/local/bin/agent/
sudo chmod +x /usr/local/bin/agent/monitor.py

# Set API URL and Key
export API_URL="http://your-api-server:8000/heartbeat"
export AGENT_API_KEY="your-agent-api-key-from-server"
# Or edit monitor.py to set them permanently

# Test the agent
python3 /usr/local/bin/agent/monitor.py
```

### 3. Install Agent as Systemd Service

```bash
# Copy service file
sudo cp /path/to/agent/vpn-monitor.service /etc/systemd/system/

# Edit service file to set your API URL
sudo nano /etc/systemd/system/vpn-monitor.service
# Update the Environment lines:
# Environment="API_URL=http://your-api-server:8000/heartbeat"
# Environment="AGENT_API_KEY=your-agent-api-key-from-server"

# Reload systemd
sudo systemctl daemon-reload

# Enable and start service
sudo systemctl enable vpn-monitor
sudo systemctl start vpn-monitor

# Check status
sudo systemctl status vpn-monitor

# View logs
sudo journalctl -u vpn-monitor -f
```

## 📁 Project Structure

```
.
├── agent/
│   ├── monitor.py              # VPN server monitoring agent
│   └── vpn-monitor.service     # Systemd service file
├── api/
│   ├── main.py                 # FastAPI application
│   ├── models.py               # Pydantic models
│   ├── database.py             # MongoDB & Redis connections
│   ├── auth.py                 # Authentication & authorization
│   ├── worker.py               # Background monitoring worker
│   └── requirements.txt        # Python dependencies
├── dashboard/
│   └── index.html              # Vue.js dashboard (SPA)
├── docker-compose.yml          # Docker orchestration
├── Dockerfile                  # API container image
└── README.md                   # This file
```

## 🔧 Configuration

### Agent Configuration

**Environment Variables:**
- `API_URL` - API heartbeat endpoint (default: `http://srvlist.app.aqibs.dev:8000/heartbeat`)
- `AGENT_API_KEY` - Secret key for authentication (Must match API server)

**Config File:** `/usr/local/bin/agent/agent_config.json`
```json
{
    "ip": "1.2.3.4",
    "countryCode": "DE",
    "country": "Germany",
    "region": "Bavaria",
    "city": "Munich"
}
```

**Monitoring Interval:** 2 minutes (120 seconds) - Edit `INTERVAL` in `monitor.py`

**Service Mapping:**
```python
SERVICES_MAP = {
    "wg-quick@wg0": "wg",      # WireGuard
    "openvpn@server": "ov",     # OpenVPN
    "squid": "sq",              # Squid Proxy
    "x-ui": "vr"                # X-UI/V2Ray
}
```

### API Configuration

**Environment Variables:**
- `MONGO_URL` - MongoDB connection string
- `REDIS_URL` - Redis connection string
- `SECRET_KEY` - JWT secret key (generate with `openssl rand -hex 32`)
- `AGENT_API_KEY` - Agent authentication key (generate with `openssl rand -hex 32`)

**Database Collections:**
- `servers` - Server heartbeat data
- `users` - User accounts

### Dashboard Configuration

The dashboard automatically connects to the API on the same domain. If you need to change this, edit line 290 in `dashboard/index.html`:

```javascript
const API_URL = '';  // Empty = same origin
// Or set to full URL:
// const API_URL = 'http://your-api-server:8000';
```

## 👥 User Management

### Roles

1. **readonly** - View servers only
2. **admin** - View and configure servers
3. **superadmin** - Full access including user management

### API Endpoints

```bash
# Login
POST /token
Body: username=admin&password=admin

# Get current user
GET /users/me
Headers: Authorization: Bearer <token>

# List users (superadmin only)
GET /users

# Create user (superadmin only)
POST /users
Body: {"username": "newuser", "password": "pass123", "role": "readonly"}

# Delete user (superadmin only)
DELETE /users/{username}

# Change own password
POST /users/change-password?old_password=old&new_password=new

# Reset user password (superadmin only)
POST /users/{username}/reset-password?new_password=newpass
```

## 🖥️ Server Management

### API Endpoints

```bash
# List all servers (dashboard view)
GET /servers?all_servers=true

# List active & enabled servers only (client view)
GET /servers

# Update server configuration
PATCH /server/{ip}/config
Body: {"gaming": true, "streaming": false, "paid": true, "enabled": true}
```

### Server Flags

- **gaming** - Optimized for gaming traffic
- **streaming** - Optimized for streaming services
- **paid** - Premium/paid server
- **enabled** - Server is active and available to clients

## 📊 Monitoring

### Metrics Collected

- **CPU Usage** - Average over 5-minute interval (0-100%)
- **RAM Usage** - Current memory utilization (0-100%)
- **Network Usage** - Throughput vs capacity (0-100%)
- **Service Status** - Active/Inactive for each VPN service
- **Heartbeat** - Last seen timestamp

### Status Determination

- **active** - Heartbeat received within last 4 minutes
- **down** - No heartbeat for 4+ minutes (set by background worker)

## 🔒 Security

### Best Practices

1. **Change default credentials** immediately
2. **Use strong SECRET_KEY** for JWT tokens
3. **Enable HTTPS** in production (use reverse proxy like Nginx)
4. **Restrict MongoDB/Redis** access to localhost or private network
5. **Use firewall rules** to limit API access
6. **Regular backups** of MongoDB data

### Production Deployment

```bash
# Use environment variables for secrets
export SECRET_KEY=$(openssl rand -hex 32)
export MONGO_URL="mongodb://username:password@mongo:27017/vpnmonitor?authSource=admin"
export REDIS_URL="redis://:password@redis:6379/0"

# Run with production settings
docker-compose -f docker-compose.prod.yml up -d
```

## 🐛 Troubleshooting

### Agent Issues

```bash
# Check if agent is running
sudo systemctl status vpn-monitor

# View recent logs
sudo journalctl -u vpn-monitor -n 50

# Test manually
python3 /usr/local/bin/agent/monitor.py

# Check config file
cat /usr/local/bin/agent/agent_config.json

# Delete config to regenerate
sudo rm /usr/local/bin/agent/agent_config.json
sudo systemctl restart vpn-monitor
```

### API Issues

```bash
# Check container logs
docker-compose logs -f api

# Check MongoDB connection
docker-compose exec mongo mongosh --eval "db.serverStatus()"

# Check Redis connection
docker-compose exec redis redis-cli ping

# Restart services
docker-compose restart
```

### Dashboard Issues

- **Can't login:** Check browser console for errors, verify API is running
- **Servers not showing:** Check agent is running and sending heartbeats
- **Country codes wrong:** Delete `agent_config.json` on agents and restart

## 📝 API Documentation

Once the API is running, visit:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## 🔄 Updates & Maintenance

### Updating Agents

```bash
# Copy new monitor.py
sudo cp /path/to/new/monitor.py /usr/local/bin/agent/
sudo systemctl restart vpn-monitor
```

### Updating API

```bash
# Pull new code
git pull

# Rebuild and restart
docker-compose down
docker-compose up -d --build
```

### Database Backup

```bash
# Backup MongoDB
docker-compose exec mongo mongodump --out=/backup
docker cp $(docker-compose ps -q mongo):/backup ./mongodb-backup-$(date +%Y%m%d)

# Restore MongoDB
docker cp ./mongodb-backup-20231127 $(docker-compose ps -q mongo):/restore
docker-compose exec mongo mongorestore /restore
```

## 📜 License

This project is proprietary software for Mect VPN.

## 🤝 Support

For issues or questions, contact the development team.

**Aqib Shahzad:** aqib.shahzad4485@gmail.com

---

**Version:** 2.1
**Last Updated:** 2025-11-27
**Changes:** Added Agent API Key Authentication
