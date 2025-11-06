local lib = require("lib")

local M = {}

local function list_home_files()
  local pipe = io.popen("find /home", "r")
  local lines = {}
  while true do
    local line = pipe:read("*l")
    if line then table.insert(lines, line) else break end
  end
  pipe:close()
  return lines
end

function M.check_harmful_files()
  lib.log("find /home -type f \\( -name '*.ogg' -o -name '*.mp3' \\) | xargs -n1 rm", "Remove prohibited files")
  lib.log("rm -rf /usr/games/*", "Remove any game files")
end

function M.check_syn_cookies()
  -- Bro, there's no way this would actually be on a comp
  local pipe = io.open("/etc/sysctl.conf", "r")
  for line in pipe:lines() do
    if line:match("^net.ipv4.tcp_syncookies=0") then
      lib.log("sysctl net.ipv4.tcp_syncookies=1", "Enable TCP SYN cookies")
    end
  end
end

function M.check_firewall()
  -- make sure ufw is installed
  if not lib.contains(lib.list_installed_packages(), "ufw") then
    lib.log("apt install ufw", "Install package: ufw")
  end

  local pipe = io.open("/etc/ufw/ufw.conf")
  for line in pipe:lines() do
    if line:match("^ENABLED=no$") then
      lib.log("ufw enable", "Enable firewall")
    end
  end
end

return M
