local lib = require("lib")

local M = {}

local SENSITIVE_FILES = {
  { path = "/etc/shadow",       mode = "640", owner = "root:shadow" },
  { path = "/etc/gshadow",      mode = "640", owner = "root:shadow" },
  { path = "/etc/passwd",       mode = "644", owner = "root:root" },
  { path = "/etc/group",        mode = "644", owner = "root:root" },
  { path = "/etc/sudoers",      mode = "0440", owner = "root:root" },
  { path = "/etc/crontab",      mode = "600", owner = "root:root" },
  { path = "/etc/ssh/sshd_config", mode = "600", owner = "root:root" }
}

local RISKY_SUID_BINARIES = {
  "/bin/bash",
  "/bin/sh",
  "/bin/dash",
  "/usr/bin/python3",
  "/usr/bin/python",
  "/usr/bin/perl",
  "/usr/bin/awk",
  "/usr/bin/find",
  "/usr/bin/nc",
  "/usr/bin/netcat",
  "/usr/bin/nmap",
  "/usr/bin/vim",
  "/usr/bin/nano",
  "/usr/bin/env"
}

local function check_file_permissions()
  for _, entry in ipairs(SENSITIVE_FILES) do
    local pipe = io.popen("stat -c '%a %U:%G' '" .. entry.path .. "' 2>/dev/null")
    if pipe then
      local stat_out = pipe:read("*l")
      pipe:close()

      if stat_out then
        local current_mode, current_owner = stat_out:match("^(%d+)%s+(%S+)$")
        
        if current_mode and current_mode ~= entry.mode then
          lib.log("chmod " .. entry.mode .. " '" .. entry.path .. "'", "Fix permissions on " .. entry.path)
        end

        if current_owner and current_owner ~= entry.owner then
          lib.log("chown " .. entry.owner .. " '" .. entry.path .. "'", "Fix ownership on " .. entry.path)
        end
      end
    end
  end
end

local function check_suid_backdoors()
  for _, binary in ipairs(RISKY_SUID_BINARIES) do
    local pipe = io.popen("stat -c '%a' '" .. binary .. "' 2>/dev/null")
    if pipe then
      local mode = pipe:read("*l")
      pipe:close()

      if mode then
        local mode_num = tonumber(mode, 8)
        if mode_num and (math.floor(mode_num / 2048) % 4 ~= 0) then
          lib.log("chmod u-s,g-s '" .. binary .. "'", "Remove SUID/SGID backdoor bit from " .. binary)
        end
      end
    end
  end
end

local function check_world_writable()
  local pipe = io.popen("find /etc /var /usr -type f -perm -0002 2>/dev/null")
  if pipe then
    for file in pipe:lines() do
      lib.log("chmod o-w '" .. file .. "'", "Remove world-writable permission from " .. file)
    end
    pipe:close()
  end
end

function M.check_special_files()
  check_file_permissions()
  check_suid_backdoors()
  check_world_writable()
end

return M
