from fastapi import FastAPI, BackgroundTasks, HTTPException, Depends, status, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
from database import db
from models import HeartbeatPayload, ServerResponse, ServerConfigUpdate
from worker import monitor_servers
import asyncio
import json
import random
import string
import os
from datetime import datetime, timedelta
from auth import (
    User, UserCreate, UserInDB, Token, 
    get_current_active_user, get_admin_user, get_super_admin_user,
    verify_password, get_password_hash, create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.connect()
    
    # Create default admin user if not exists
    admin_user = await db.db.users.find_one({"username": "admin"})
    if not admin_user:
        hashed_password = get_password_hash("admin")
        user_in_db = UserInDB(
            username="admin",
            hashed_password=hashed_password,
            role="superadmin"
        )
        await db.db.users.insert_one(user_in_db.model_dump())
        print("Created default admin user (admin/admin)")

    # Start background monitor
    asyncio.create_task(monitor_servers())
    yield
    await db.close()

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount Dashboard
app.mount("/dashboard", StaticFiles(directory="dashboard", html=True), name="dashboard")

@app.get("/")
async def root():
    return {"message": "VPN Monitor API. Go to /dashboard/ for the UI."}

@app.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    user_dict = await db.db.users.find_one({"username": form_data.username})
    if not user_dict:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = UserInDB(**user_dict)
    if not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=User)
async def read_users_me(current_user: User = Depends(get_current_active_user)):
    return current_user

@app.post("/users", response_model=User)
async def create_user(user: UserCreate, current_user: User = Depends(get_super_admin_user)):
    user_dict = await db.db.users.find_one({"username": user.username})
    if user_dict:
        raise HTTPException(status_code=400, detail="Username already registered")
    hashed_password = get_password_hash(user.password)
    user_in_db = UserInDB(
        **user.model_dump(),
        hashed_password=hashed_password
    )
    await db.db.users.insert_one(user_in_db.model_dump())
    return user_in_db

@app.get("/users", response_model=list[User])
async def read_users(current_user: User = Depends(get_super_admin_user)):
    cursor = db.db.users.find({})
    users = await cursor.to_list(length=1000)
    return users

@app.delete("/users/{username}")
async def delete_user(username: str, current_user: User = Depends(get_super_admin_user)):
    if username == "admin":
        raise HTTPException(status_code=400, detail="Cannot delete default admin")
    result = await db.db.users.delete_one({"username": username})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="User not found")
    return {"status": "deleted"}

@app.post("/users/change-password")
async def change_password(old_password: str, new_password: str, current_user: User = Depends(get_current_active_user)):
    """Allow any logged-in user to change their own password"""
    # Get current user from DB
    user_dict = await db.db.users.find_one({"username": current_user.username})
    if not user_dict:
        raise HTTPException(status_code=404, detail="User not found")
    
    user_in_db = UserInDB(**user_dict)
    
    # Verify old password
    if not verify_password(old_password, user_in_db.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect current password")
    
    # Hash and update new password
    hashed_password = get_password_hash(new_password)
    await db.db.users.update_one(
        {"username": current_user.username},
        {"$set": {"hashed_password": hashed_password}}
    )
    
    return {"status": "password_changed"}

@app.post("/users/{username}/reset-password")
async def reset_user_password(username: str, new_password: str, current_user: User = Depends(get_super_admin_user)):
    """Allow superadmin to reset any user's password without knowing the old one"""
    # Hash and update password
    hashed_password = get_password_hash(new_password)
    result = await db.db.users.update_one(
        {"username": username},
        {"$set": {"hashed_password": hashed_password}}
    )
    
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {"status": "password_reset"}

def generate_server_id():
    """Generate a unique server ID like srv-a1b2"""
    return "srv-" + "".join(random.choices(string.ascii_lowercase + string.digits, k=8))

@app.post("/heartbeat")
async def receive_heartbeat(payload: HeartbeatPayload, x_api_key: str = Header(None)):
    """
    Receives heartbeat from VPN Agent.
    Updates Redis (Cache) and MongoDB (Persistence).
    Requires X-API-Key header for authentication.
    """
    # Verify agent API key
    expected_key = os.getenv("AGENT_API_KEY")
    
    if not expected_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server configuration error: AGENT_API_KEY not configured"
        )
    
    if not x_api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing API key. Include X-API-Key header."
        )
    
    if x_api_key != expected_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )
    server_key = f"server:{payload.ip}"
    
    # 1. Check Cache
    cached_data = await db.redis.get(server_key)
    
    should_update_db = True
    if cached_data:
        cached_obj = json.loads(cached_data)
        # Merge incoming payload with cached config fields to preserve manual settings
        # Only config fields (gaming, streaming, paid, enabled) should be preserved from cache
        for field in ["gaming", "streaming", "paid", "enabled"]:
            if field in cached_obj and field not in payload.model_dump():
                # This won't happen since HeartbeatPayload doesn't include these fields
                # But we keep the structure for consistency
                pass
        # Optimization: Only update DB if status changed or > 5 mins since last DB write?
        # For now, let's update DB on every heartbeat to ensure 'last_heartbeat' is accurate for the monitor.
        pass

    # 2. Update/Insert in MongoDB
    update_data = payload.model_dump()
    update_data["last_heartbeat"] = datetime.utcnow()
    update_data["status"] = "active"
    
    # Use upsert
    result = await db.db.servers.update_one(
        {"ip": payload.ip},
        {
            "$set": update_data,
            "$setOnInsert": {
                "server_id": generate_server_id(),
                "first_heartbeat": datetime.utcnow(),
                "gaming": False,
                "streaming": False,
                "paid": True,
                "enabled": True
            }
        },
        upsert=True
    )

    # 3. Update Redis Cache (with 10 min TTL)
    # We store the full object for fast retrieval
    final_cache_data = update_data
    if cached_data:
        try:
            current_cache = json.loads(cached_data)
            current_cache.update(update_data)
            final_cache_data = current_cache
        except:
            pass
            
    await db.redis.set(server_key, json.dumps(final_cache_data, default=str), ex=600)
    
    return {"status": "ok"}

@app.get("/servers", response_model=list[ServerResponse])
async def list_servers(all_servers: bool = False, current_user: User = Depends(get_current_active_user)):
    """
    Returns list of servers.
    - Default: Returns only ACTIVE and ENABLED servers (for clients).
    - ?all_servers=true: Returns ALL servers (for dashboard/admin).
    """
    query = {}
    if not all_servers:
        query = {"status": "active", "enabled": True}
        
    cursor = db.db.servers.find(query)
    servers = await cursor.to_list(length=1000)
    return servers

@app.patch("/server/{ip}/config")
async def update_server_config(ip: str, config: ServerConfigUpdate, current_user: User = Depends(get_admin_user)):
    """
    Manually update server configuration (gaming, streaming, paid, enabled).
    """
    update_fields = config.model_dump(exclude_unset=True)
    
    if not update_fields:
        raise HTTPException(status_code=400, detail="No fields to update")
        
    result = await db.db.servers.update_one(
        {"ip": ip},
        {"$set": update_fields}
    )
    
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Server not found")
        
    # Update Redis Cache
    server_key = f"server:{ip}"
    cached_data = await db.redis.get(server_key)
    if cached_data:
        data = json.loads(cached_data)
        data.update(update_fields)
        await db.redis.set(server_key, json.dumps(data, default=str), ex=600)
        
    return {"status": "updated", "updated_fields": update_fields}
