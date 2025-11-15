local lib = require("lib")

local M = {}

function M.check_harmful_files()
  lib.log("find /home -type f \\( -name '*.ogg' -o -name '*.mp3' \\) -print0 | xargs -0 -n1 rm", "Remove prohibited files")
  lib.log("rm -rf /usr/games/*", "Remove any game files")
end

function set_sysctl(opt, old_val, new_val)
  local pipe = io.open("/etc/sysctl.conf", "r")
  for line in pipe:lines() do
    if line:match("^"..opt.."%s*=%s*"..old_val.."$") then
      lib.log("sed -i 's/^"..opt.."\\s*=\\s*"..old_val.."$/"..opt.."="..new_val.."/' /etc/sysctl.conf", "Toggle "..opt.." in sysctl")
      lib.log("sysctl -p", "Reload sysctl")
    end
  end
end

function M.check_sysctl()
  set_sysctl("net.ipv4.tcp_syncookies", "0", "1")
  set_sysctl("net.ipv4.ip_forward", "1", "0")
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

function M.check_guest_login()
  local lightdm = io.open("/etc/lightdm/lightdm.conf", "r")
  for line_nr, line in lib.enumerate(lightdm:lines()) do
    if line:match("^[Seat:*]") then
      lib.log("sed -Ei '"..line_nr.."s/$/\nallow-guest=false\n/' /etc/lightdm/lightdm.conf", "Disable guest account")
    end
  end
end

function M.check_shadow_permissions()
  local shadow_permissions = io.popen("stat -c '%a' /etc/shadow", "r"):read("*a")
  if not shadow_permissions:match("640") then
    lib.log("chmod 640 /etc/shadow", "Secure shadow file")
  end
end

return M
