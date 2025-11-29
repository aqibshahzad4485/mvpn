import time
import json
import os
import requests
import subprocess
import sys
import socket

# Configuration
API_URL = os.getenv("API_URL", "http://srvlist.app.aqibs.dev:8000/heartbeat")
AGENT_API_KEY = os.getenv("AGENT_API_KEY")
CONFIG_FILE = "/usr/local/bin/agent/agent_config.json"
INTERVAL = 120  # 2 minutes

# Validate API key is configured
if not AGENT_API_KEY:
    print("ERROR: AGENT_API_KEY environment variable is not set!")
    print("Please configure AGENT_API_KEY in your environment or systemd service file.")
    sys.exit(1)

def get_cpu_stats():
    """
    Reads /proc/stat and returns a list of CPU times.
    Returns None if not available.
    """
    try:
        with open('/proc/stat', 'r') as f:
            line = f.readline()
            if line.startswith('cpu '):
                # cpu  user nice system idle iowait irq softirq steal guest guest_nice
                parts = line.split()[1:]
                return [int(x) for x in parts]
    except FileNotFoundError:
        return None
    except Exception as e:
        print(f"Error reading CPU stats: {e}")
        return None

def calculate_cpu_percent(prev, curr):
    """
    Calculates CPU usage percentage between two stats snapshots.
    """
    if not prev or not curr:
        return 0.0
    
    # idle = idle + iowait
    prev_idle = prev[3] + prev[4]
    curr_idle = curr[3] + curr[4]
    
    prev_total = sum(prev)
    curr_total = sum(curr)
    
    total_diff = curr_total - prev_total
    idle_diff = curr_idle - prev_idle
    
    if total_diff == 0:
        return 0.0
        
    return round(100 * (1 - (idle_diff / total_diff)), 2)


def get_public_ip_info():
    try:
        response = requests.get("http://ip-api.com/json/")
        if response.status_code == 200:
            return response.json()
    except Exception as e:
        print(f"Error fetching IP info: {e}")
    return None

def load_or_init_config():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r") as f:
            return json.load(f)
    
    print("Initializing Agent Configuration...")
    ip_info = get_public_ip_info()
    if not ip_info:
        print("Could not fetch IP info. Exiting.")
        sys.exit(1)
        
    config = {
        "ip": ip_info.get("query"),
        "countryCode": ip_info.get("countryCode"),
        "country": ip_info.get("country"),
        "region": ip_info.get("regionName"),
        "city": ip_info.get("city")
    }
    
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f, indent=4)
        
    return config

def check_service_status(service_name):
    """
    Checks if a systemd service is active.
    """
    try:
        # Check if active
        result = subprocess.run(
            ["systemctl", "is-active", service_name], 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            text=True
        )
        is_active = result.stdout.strip() == "active"
        return is_active
    except FileNotFoundError:
        # systemctl might not exist on non-systemd systems (e.g. docker container without init)
        return False
    except Exception as e:
        print(f"Error checking {service_name}: {e}")
        return False

def get_ram_usage():
    """
    Calculates RAM usage percentage.
    """
    try:
        with open('/proc/meminfo', 'r') as f:
            lines = f.readlines()
            
        mem_total = 0
        mem_available = 0
        
        for line in lines:
            if line.startswith('MemTotal:'):
                mem_total = int(line.split()[1])
            elif line.startswith('MemAvailable:'):
                mem_available = int(line.split()[1])
                
        if mem_total > 0:
            return round(((mem_total - mem_available) / mem_total) * 100, 2)
    except Exception:
        pass
    return 0.0

def get_network_usage(interval=1):
    """
    Calculates Network usage percentage based on throughput vs capacity.
    Defaults to eth0 if primary interface cannot be determined.
    """
    try:
        # Find primary interface
        route = subprocess.check_output(["ip", "route"], text=True)
        default_route = [line for line in route.splitlines() if "default" in line]
        if default_route:
            iface = default_route[0].split("dev")[1].split()[0]
        else:
            iface = "eth0"
            
        # Get capacity (speed) in Mbps
        try:
            with open(f"/sys/class/net/{iface}/speed", "r") as f:
                speed_mbps = int(f.read().strip())
                if speed_mbps < 0: # Virtual interfaces might report -1
                    speed_mbps = 1000
        except:
            speed_mbps = 1000 # Default to 1Gbps
            
        capacity_bps = speed_mbps * 1_000_000
        
        def get_bytes():
            with open(f"/sys/class/net/{iface}/statistics/rx_bytes", "r") as f:
                rx = int(f.read().strip())
            with open(f"/sys/class/net/{iface}/statistics/tx_bytes", "r") as f:
                tx = int(f.read().strip())
            return rx + tx
            
        bytes_start = get_bytes()
        time.sleep(interval)
        bytes_end = get_bytes()
        
        # Calculate bits per second
        bps = (bytes_end - bytes_start) * 8 / interval
        
        return round((bps / capacity_bps) * 100, 2)
        
    except Exception as e:
        print(f"Error checking network: {e}")
        return 0.0

def send_heartbeat(config, services_map, cpu_percent, ram_percent, net_percent):
    service_statuses = []
    for svc_name, svc_code in services_map.items():
        active = check_service_status(svc_name)
        service_statuses.append({
            "name": svc_code,
            "active": active
        })

    payload = {
        **config,
        "hostname": socket.gethostname(),
        "services": service_statuses,
        "load": {
            "cpu": cpu_percent,
            "ram": ram_percent,
            "net": net_percent
        }
    }
    
    try:
        print(f"Sending heartbeat... Load: {cpu_percent}%")
        headers = {
            "X-API-Key": AGENT_API_KEY,
            "Content-Type": "application/json"
        }
        res = requests.post(API_URL, json=payload, headers=headers)
        print(f"Response: {res.status_code}")
        
        # Log authentication errors
        if res.status_code == 401:
            print("ERROR: Authentication failed. Check AGENT_API_KEY configuration.")
        elif res.status_code != 200:
            print(f"WARNING: Unexpected response: {res.text}")
    except Exception as e:
        print(f"Failed to send heartbeat: {e}")


def main():
    config = load_or_init_config()
    print(f"Agent running for IP: {config['ip']}")
    
    SERVICES_MAP = {
        "wg-quick@wg0": "wg",
        "openvpn@server": "ov",
        "squid": "sq",
        "x-ui": "vr"
    }
    
    # Initialize CPU tracking
    prev_cpu = get_cpu_stats()
    cpu_samples = []
    ram_samples = []
    net_samples = []
    
    # Send immediate heartbeat on startup
    ram_percent = get_ram_usage()
    net_percent = get_network_usage(interval=1)
    send_heartbeat(config, SERVICES_MAP, 0, ram_percent, net_percent)
    
    beat_count = 0
    sample_interval = 30  # Sample every 30 seconds
    
    while True:
        time.sleep(sample_interval)
        beat_count += 1
        
        # Sample CPU
        curr_cpu = get_cpu_stats()
        cpu_percent = calculate_cpu_percent(prev_cpu, curr_cpu)
        prev_cpu = curr_cpu
        cpu_samples.append(cpu_percent)
        
        # Sample RAM
        ram_samples.append(get_ram_usage())
        
        # Sample Network
        net_samples.append(get_network_usage(interval=1))
        
        # Send heartbeat every INTERVAL (5 minutes = 10 samples at 30s each)
        if beat_count * sample_interval >= INTERVAL:
            avg_cpu = round(sum(cpu_samples) / len(cpu_samples), 2) if cpu_samples else 0
            avg_ram = round(sum(ram_samples) / len(ram_samples), 2) if ram_samples else 0
            avg_net = round(sum(net_samples) / len(net_samples), 2) if net_samples else 0
            
            send_heartbeat(config, SERVICES_MAP, avg_cpu, avg_ram, avg_net)
            
            # Reset for next interval
            cpu_samples.clear()
            ram_samples.clear()
            net_samples.clear()
            beat_count = 0

if __name__ == "__main__":
    main()
