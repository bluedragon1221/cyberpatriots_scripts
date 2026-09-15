local lib = require("lib")

local M = {}

function M.check_harmful_files()
  local media_check = io.popen("find /home -type f \\( -name '*.ogg' -o -name '*.mp3' \\) -print0 2>/dev/null | grep -zq . && echo 'yes'")
  if media_check then
    local result = media_check:read("*l")
    media_check:close()
    if result == "yes" then
      lib.log("find /home -type f \\( -name '*.ogg' -o -name '*.mp3' \\) -print0 | xargs -0 -n1 rm", "Remove prohibited files")
    end
  end

  local games_check = io.popen("test -d /usr/games && [ \"$(ls -A /usr/games 2>/dev/null)\" ] && echo 'yes'")
  if games_check then
    local result = games_check:read("*l")
    games_check:close()
    if result == "yes" then
      lib.log("rm -rf /usr/games/*", "Remove any game files")
    end
  end
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
  local content = lib.read_file("/etc/lightdm/lightdm.conf")
  if not content then return end

  -- Escaped brackets %[%] to match the literal section header
  if content:match("%[Seat:%*%]") then
    -- Check if allow-guest is already configured
    if not content:match("allow%-guest%s*=%s*false") then
      lib.log(
        "sed -i '/%[Seat:%*%]/a allow-guest=false' /etc/lightdm/lightdm.conf",
        "Disable guest account under [Seat:*]"
      )
    end
  end
end

function M.check_shadow_permissions()
  local shadow_permissions = io.popen("stat -c '%a' /etc/shadow", "r"):read("*a")
  if not shadow_permissions:match("640") then
    lib.log("chmod 640 /etc/shadow", "Secure shadow file")
  end
end

function M.check_sudoers()
  local sudoers_files = {}

  if io.open("/etc/sudoers", "r") then
    table.insert(sudoers_files, "/etc/sudoers")
  end

  local pipe = io.popen("find /etc/sudoers.d -type f 2>/dev/null")
  if pipe then
    for file in pipe:lines() do
      if not file:match("~") and not file:match("%.bak$") and not file:match("README") then
        table.insert(sudoers_files, file)
      end
    end
    pipe:close()
  end

  for _, filepath in ipairs(sudoers_files) do
    local content = lib.read_file(filepath)
    if content then
      local line_nr = 0
      for line in content:gmatch("[^\r\n]+") do
        line_nr = line_nr + 1
        local clean_line = line:match("^%s*(.-)%s*$")

        if clean_line ~= "" and not clean_line:match("^#") then

          if filepath ~= "/etc/sudoers" then
            if clean_line:match("NOPASSWD") or clean_line:match("ALL%s*=%s*%(") then
              lib.log("rm -f '" .. filepath .. "'", "Remove suspicious sudoers.d drop-in file: " .. filepath)
              break
            end
          end

          if clean_line:match("NOPASSWD") and not clean_line:match("^root%s") then
            lib.log("sed -i '" .. line_nr .. "s/NOPASSWD://g' '" .. filepath .. "'", "Remove NOPASSWD flag from rule in " .. filepath)
          end

          if clean_line:match("^[^#].*ALL%s*=%s*%(ALL.*%)%s*ALL") and not clean_line:match("^root%s") and not clean_line:match("^%%sudo%s") and not clean_line:match("^%%admin%s") then
            lib.log("sed -i '" .. line_nr .. "d' '" .. filepath .. "'", "Remove unauthorized blanket sudo rule in " .. filepath)
          end

          if clean_line:match("/bin/bash") or clean_line:match("/bin/sh") or clean_line:match("/usr/bin/python") or clean_line:match("netcat") or clean_line:match("/usr/bin/nc") then
            lib.log("sed -i '" .. line_nr .. "d' '" .. filepath .. "'", "Remove backdoored command rule in " .. filepath)
          end

        end
      end
    end

    local stat_pipe = io.popen("stat -c '%a %U:%G' '" .. filepath .. "' 2>/dev/null")
    if stat_pipe then
      local stat_out = stat_pipe:read("*l")
      stat_pipe:close()
      if stat_out and stat_out ~= "440 root:root" then
        lib.log("chown root:root '" .. filepath .. "' && chmod 0440 '" .. filepath .. "'", "Secure permissions on " .. filepath .. " (was " .. stat_out .. ")")
      end
    end
  end
end

return M
