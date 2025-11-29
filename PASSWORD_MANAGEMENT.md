# Password Management Guide

## For Admin Users (Emergency Password Reset)

If you forget the admin password and can't log in, you can reset it directly from the server.

### Method 1: Using the Reset Script (Recommended)

1. **SSH into your API server**:
   ```bash
   ssh root@your-server-ip
   cd /root/temp
   ```

2. **Run the reset script inside the Docker container**:
   ```bash
   docker exec -it temp_api_1 python3 reset_password.py admin new_password_here
   ```

   Replace `new_password_here` with your desired new password.

   **Example**:
   ```bash
   docker exec -it temp_api_1 python3 reset_password.py admin MyNewSecurePass123
   ```

3. **Success!** You should see:
   ```
   ✅ Password for user 'admin' has been reset successfully!
   ```

### Method 2: Direct MongoDB Access

If the script doesn't work, you can reset the password directly via MongoDB:

1. **Access MongoDB**:
   ```bash
   docker exec -it temp_mongo_1 mongosh vpn_monitor
   ```

2. **Generate a password hash** (in Python):
   ```python
   from passlib.context import CryptContext
   pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
   print(pwd_context.hash("your_new_password"))
   ```

3. **Update the password in MongoDB**:
   ```javascript
   db.users.updateOne(
       { username: "admin" },
       { $set: { hashed_password: "PASTE_HASH_HERE" } }
   )
   ```

## For Regular Users (Change Password via Dashboard)

The API endpoint `/users/change-password` is now available for users to change their own password programmatically.

### Using curl:

```bash
curl -X POST "http://your-server:8000/users/change-password" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "old_password": "current_password",
    "new_password": "new_secure_password"
  }'
```

### Response:
```json
{
  "status": "password_changed"
}
```

### Error Cases:
- **400**: Incorrect current password
- **401**: Unauthorized (invalid token)
- **404**: User not found

## Security Best Practices

1. **Default Password**: Change the default `admin/admin` password immediately after deployment
2. **Password Strength**: Use strong passwords with at least 12 characters, including uppercase, lowercase, numbers, and symbols
3. **Regular Rotation**: Change passwords every 90 days
4. **Limit Access**: Only give admin/superadmin roles to trusted users
5. **Monitor Logs**: Check for failed login attempts regularly

## Troubleshooting

### "User not found" error
- Check if the username is correct
- For Docker exec method, make sure you're using the correct container name

### "Incorrect current password" error
- Make sure you're typing the old password correctly
- Try the emergency reset method if you've forgotten it

### Script not found
- Make sure `reset_password.py` is in `/app` directory inside the container
- Rebuild the API container if needed: `docker-compose up -d --build api`
