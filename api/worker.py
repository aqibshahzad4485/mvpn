import asyncio
from datetime import datetime, timedelta
from database import db

async def monitor_servers():
    """
    Background task to check server health.
    - Mark as DOWN if no heartbeat for > 4 mins.
    - Delete if no heartbeat for > 2 days (unless static).
    """
    while True:
        try:
            if db.db is not None:
                now = datetime.utcnow()
                
                # 1. Mark stale servers as DOWN
                stale_threshold = now - timedelta(minutes=4)
                await db.db.servers.update_many(
                    {"last_heartbeat": {"$lt": stale_threshold}, "status": "active"},
                    {"$set": {"status": "down"}}
                )

                # 2. Remove dead servers (> 30 days)
                # Assuming we might add a 'static' flag later, for now just delete old ones
                dead_threshold = now - timedelta(days=30)
                await db.db.servers.delete_many(
                    {"last_heartbeat": {"$lt": dead_threshold}, "static": {"$ne": True}}
                )
                
        except Exception as e:
            print(f"Monitor Error: {e}")
        
        await asyncio.sleep(60) # Run every minute
