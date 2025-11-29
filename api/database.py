import os
from motor.motor_asyncio import AsyncIOMotorClient
import redis.asyncio as aioredis
from dotenv import load_dotenv

load_dotenv()

MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")

class Database:
    client: AsyncIOMotorClient = None
    db = None
    redis: aioredis.Redis = None

    async def connect(self):
        self.client = AsyncIOMotorClient(MONGO_URL)
        self.db = self.client.vpn_monitor
        self.redis = aioredis.from_url(REDIS_URL, decode_responses=True)
        print("Connected to MongoDB and Redis")

    async def close(self):
        self.client.close()
        await self.redis.close()
        print("Closed DB connections")

db = Database()
