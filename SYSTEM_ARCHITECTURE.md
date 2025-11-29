# System Architecture & How It Works

## 🔄 Complete Data Flow

### 1. Agent → API (Heartbeat)

```
┌──────────────────────────────────────────────────────────────┐
│ VPN Server (Agent)                                           │
│                                                              │
│  Every 2 minutes:                                           │
│  1. Collect CPU stats (from /proc/stat)                     │
│  2. Collect RAM usage (from /proc/meminfo)                  │
│  3. Collect Network usage (from /sys/class/net)             │
│  4. Check service status (systemctl is-active)              │
│  5. Calculate averages over 2-minute interval               │
│                                                              │
│  Send HTTP POST to API:                                     │
│  Headers: {"X-API-Key": "..."}                              │
│  {                                                           │
│    "ip": "1.2.3.4",                                         │
│    "countryCode": "DE",                                     │
│    "country": "Germany",                                    │
│    "city": "Munich",                                        │
│    "hostname": "vpn-de-01",                                 │
│    "services": [                                            │
│      {"name": "wg", "active": true},                        │
│      {"name": "ov", "active": false}                        │
│    ],                                                        │
│    "load": {                                                │
│      "cpu": 23.5,                                           │
│      "ram": 45.2,                                           │
│      "net": 12.8                                            │
│    }                                                         │
│  }                                                           │
└──────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP POST
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ API Server (FastAPI)                                         │
│                                                              │
│  /heartbeat endpoint:                                        │
│  1. Verify X-API-Key header                                  │
│  2. Receive payload                                          │
│  2. Check Redis cache for existing server                   │
│  3. Merge with cached config (gaming, streaming, etc.)      │
│  4. Update MongoDB with upsert:                             │
│     - Update: last_heartbeat, load, services, status        │
│     - Insert: server_id, first_heartbeat, defaults          │
│  5. Update Redis cache (TTL: 10 minutes)                    │
│  6. Return {"status": "ok"}                                 │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   MongoDB       │
                    │   Collection:   │
                    │   "servers"     │
                    └─────────────────┘
```

### 2. Background Worker (Health Monitoring)

```
┌──────────────────────────────────────────────────────────────┐
│ Background Worker (runs every 60 seconds)                    │
│                                                              │
│  Task 1: Mark stale servers as DOWN                         │
│  ────────────────────────────────────                        │
│  Find: last_heartbeat < (now - 4 minutes)                   │
│  Update: status = "down"                                     │
│                                                              │
│  Task 2: Delete dead servers                                │
│  ────────────────────────────────                            │
│  Find: last_heartbeat < (now - 30 days)                     │
│        AND static != true                                    │
│  Delete: Remove from database                               │
└──────────────────────────────────────────────────────────────┘
```

### 3. Dashboard → API (User Interaction)

```
┌──────────────────────────────────────────────────────────────┐
│ User Browser (Dashboard)                                     │
│                                                              │
│  1. Login:                                                   │
│     POST /token                                              │
│     ↓                                                        │
│     Receive JWT token                                        │
│     Store in localStorage                                    │
│                                                              │
│  2. Fetch Servers (every 5 seconds):                        │
│     GET /servers?all_servers=true                           │
│     Authorization: Bearer <token>                            │
│     ↓                                                        │
│     Receive server list                                      │
│     Update Vue reactive state                                │
│     Re-render UI                                             │
│                                                              │
│  3. Toggle Server Config:                                   │
│     PATCH /server/{ip}/config                               │
│     Body: {"gaming": true}                                   │
│     ↓                                                        │
│     Update MongoDB                                           │
│     Update Redis cache                                       │
│     Next fetch shows updated state                           │
└──────────────────────────────────────────────────────────────┘
```

## 🗄️ Database Schema

### MongoDB - `servers` Collection

```javascript
{
  "_id": ObjectId("..."),
  "server_id": "srv-a1b2c3d4",           // Unique identifier
  "ip": "1.2.3.4",                       // Primary key
  "hostname": "vpn-de-01",
  "countryCode": "DE",                   // ISO code
  "country": "Germany",                  // Full name
  "region": "Bavaria",
  "city": "Munich",
  
  // Status
  "status": "active",                    // active | down
  "last_heartbeat": ISODate("2025-11-27T12:00:00Z"),
  "first_heartbeat": ISODate("2025-11-20T08:30:00Z"),
  
  // Load metrics
  "load": {
    "cpu": 23.5,
    "ram": 45.2,
    "net": 12.8
  },
  
  // Services
  "services": [
    {"name": "wg", "active": true},
    {"name": "ov", "active": false},
    {"name": "sq", "active": true},
    {"name": "vr", "active": false}
  ],
  
  // Configuration flags (set by admin)
  "gaming": false,
  "streaming": true,
  "paid": true,
  "enabled": true,
  "static": false                        // If true, never auto-delete
}
```

### MongoDB - `users` Collection

```javascript
{
  "_id": ObjectId("..."),
  "username": "admin",
  "hashed_password": "$2b$12$...",      // bcrypt hash
  "role": "superadmin"                   // readonly | admin | superadmin
}
```

### Redis Cache

```
Key: "server:1.2.3.4"
TTL: 600 seconds (10 minutes)
Value: JSON string of server object (same as MongoDB)

Purpose:
- Fast reads for /servers endpoint
- Reduce MongoDB load
- Auto-expire stale data
```

## 🔐 Authentication Flow

```
1. User submits login form
   ↓
2. POST /token with username & password
   ↓
3. API verifies credentials:
   - Fetch user from MongoDB
   - bcrypt.verify(password, hashed_password)
   ↓
4. Generate JWT token:
   - Payload: {"sub": username}
   - Expiry: 30 days
   - Sign with SECRET_KEY
   ↓
5. Return {"access_token": "eyJ...", "token_type": "bearer"}
   ↓
6. Dashboard stores token in localStorage
   ↓
7. All subsequent requests include:
   Authorization: Bearer eyJ...
   ↓
8. API validates token on each request:
   - Decode JWT
   - Verify signature
   - Check expiry
   - Load user from DB
   - Check role permissions

### Agent Authentication

```
1. Agent starts up
   ↓
2. Loads AGENT_API_KEY from environment
   ↓
3. Sends Heartbeat:
   POST /heartbeat
   Header: X-API-Key: <key>
   ↓
4. API verifies key:
   - Compare with server's AGENT_API_KEY
   - If match: Process heartbeat
   - If mismatch: Return 401 Unauthorized
```
```

## 📊 Load Calculation (Agent)

### CPU Usage
```python
# Read /proc/stat twice with interval
prev_stats = [user, nice, system, idle, iowait, ...]
time.sleep(30)
curr_stats = [user, nice, system, idle, iowait, ...]

# Calculate
total_diff = sum(curr_stats) - sum(prev_stats)
idle_diff = (curr_idle + curr_iowait) - (prev_idle + prev_iowait)
cpu_percent = 100 * (1 - (idle_diff / total_diff))

# Average over 2 minutes (4 samples at 30s each)
avg_cpu = sum(samples) / len(samples)
```

### RAM Usage
```python
# Read /proc/meminfo
MemTotal = 16000000 KB
MemAvailable = 8000000 KB

ram_percent = ((MemTotal - MemAvailable) / MemTotal) * 100
```

### Network Usage
```python
# Read /sys/class/net/{interface}/statistics/
rx_bytes_start = 1000000
tx_bytes_start = 500000
time.sleep(1)
rx_bytes_end = 1100000
tx_bytes_end = 550000

# Calculate throughput
total_bytes = (rx_bytes_end + tx_bytes_end) - (rx_bytes_start + tx_bytes_start)
bits_per_second = total_bytes * 8

# Get interface capacity
speed_mbps = 1000  # From /sys/class/net/{interface}/speed
capacity_bps = speed_mbps * 1_000_000

# Calculate percentage
net_percent = (bits_per_second / capacity_bps) * 100
```

## 🔄 Update Cycle Timing

```
Agent Samples:
├─ t=0s:   Sample 1 (CPU, RAM, NET)
├─ t=30s:  Sample 2
├─ t=60s:  Sample 3
├─ t=90s:  Sample 4
└─ t=120s: Calculate averages → Send heartbeat

API Worker:
├─ t=0s:   Check all servers
├─ t=60s:  Check all servers
├─ t=120s: Check all servers
└─ ...

Dashboard:
├─ t=0s:   Fetch servers
├─ t=5s:   Fetch servers
├─ t=10s:  Fetch servers
└─ ...
```

## 🎯 Key Design Decisions

### Why Redis Cache?
- **Fast reads**: Dashboard fetches every 5s, MongoDB would be overloaded
- **Auto-expiry**: Stale data automatically removed
- **Atomic updates**: No race conditions

### Why MongoDB?
- **Flexible schema**: Easy to add new fields
- **Upsert operations**: Simplifies agent logic
- **Good for time-series**: Heartbeat data is time-series
- **Aggregation**: Can add analytics later

### Why JWT Tokens?
- **Stateless**: No session storage needed
- **Scalable**: Can run multiple API instances
- **Long-lived**: 30-day expiry reduces login friction

### Why Background Worker?
- **Decoupled**: Health checks independent of heartbeats
- **Reliable**: Runs even if no heartbeats
- **Efficient**: Batch updates every minute

### Why 2-Minute Heartbeat?
- **Balance**: Not too frequent (bandwidth), not too slow (detection)
- **4-minute timeout**: Allows 1 missed beat before marking down
- **30-second sampling**: Smooth out CPU/network spikes

## 🚨 Error Handling

### Agent Failures
- **Network error**: Retry on next interval (2 min)
- **API down**: Keep trying, no data loss
- **Auth failed**: Log error (check API key)
- **Service check fails**: Report as inactive

### API Failures
- **MongoDB down**: Return 500, agent retries
- **Redis down**: Fall back to MongoDB (slower)
- **Invalid token**: Return 401, dashboard redirects to login

### Dashboard Failures
- **API unreachable**: Show error message
- **Token expired**: Redirect to login
- **WebSocket closed**: Fallback to polling (already using polling)

## 📈 Performance Characteristics

### Current Load (100 servers)
- **MongoDB writes**: 100 servers × 30 heartbeats/hour = 3,000 writes/hour
- **MongoDB reads**: 1 dashboard × 720 reads/hour = 720 reads/hour
- **Redis reads**: Same as MongoDB reads (but much faster)
- **API CPU**: < 5%
- **API RAM**: ~200 MB

### Scalability Limits
- **1,000 servers**: No problem
- **10,000 servers**: Need Redis cluster, MongoDB replica set
- **100,000 servers**: Need load balancer, multiple API instances
