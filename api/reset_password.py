#!/usr/bin/env python3
"""
Emergency Password Reset Script
Run this on the server to reset a user's password if they forgot it.

Usage:
    python3 reset_password.py <username> <new_password>

Example:
    python3 reset_password.py admin newpassword123
"""

import sys
from passlib.context import CryptContext
from pymongo import MongoClient

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def reset_password(username, new_password):
    # Connect to MongoDB
    client = MongoClient("mongodb://mongo:27017")
    db = client.vpn_monitor
    
    # Hash the new password
    hashed_password = pwd_context.hash(new_password)
    
    # Update the user
    result = db.users.update_one(
        {"username": username},
        {"$set": {"hashed_password": hashed_password}}
    )
    
    if result.matched_count == 0:
        print(f"❌ Error: User '{username}' not found!")
        return False
    
    print(f"✅ Password for user '{username}' has been reset successfully!")
    return True

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 reset_password.py <username> <new_password>")
        print("Example: python3 reset_password.py admin newpassword123")
        sys.exit(1)
    
    username = sys.argv[1]
    new_password = sys.argv[2]
    
    reset_password(username, new_password)
