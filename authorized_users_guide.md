# Authorized Users Configuration Guide
To enable automated user and group auditing, create `authorized_users.lua` in this dir.

## Structure
```lua
return {
  admins = {
    "alice",
    "bob"
  },
  users = {
    "charlie",
    "david"
  }
}
