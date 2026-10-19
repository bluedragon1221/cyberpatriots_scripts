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

`groups` maps a group name to the users that must be in it. Missing groups are created
(`addgroup`) and missing members are appended (`gpasswd -a`).

`software` lists packages from `BAD_PROGRAMS` (see `packages.lua`) that the README says to keep,
e.g. `software = { "wireshark", "ophcrack" }`. They are skipped when purging.
