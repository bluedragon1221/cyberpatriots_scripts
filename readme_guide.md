# Readme Lua Configuration Guide
The `readme.lua` file acts as the single source of truth for both user management and service requirements across all audit modules.

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
  },
  services = {
    ftp = false,
    apache = true,
    ssh = true,
    mysql = false
  }
}
