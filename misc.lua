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

  local listing = lib.capture("find /usr/games -mindepth 1 -maxdepth 1 ! -type d 2>/dev/null")
  for path in listing:gmatch("[^\r\n]+") do
    if not lib.run_ok("dpkg -S " .. lib.shell_quote(path) .. " >/dev/null 2>&1") then
      lib.log("rm -f " .. lib.shell_quote(path), "Remove unpackaged file in /usr/games: " .. path)
    end
  end
end

local function check_sysctl_key(key, want)
  local runtime = lib.read_file("/proc/sys/" .. key:gsub("%.", "/"))
  runtime = runtime and runtime:match("^%s*(.-)%s*$")

  local key_re = key:gsub("%.", "[.]")
  local grep = lib.capture("grep -HsE '^[[:space:]]*" .. key_re .. "[[:space:]]*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null")

  local bad_files = {}
  for file, val in grep:gmatch("([^:\r\n]+):[^=\r\n]*=%s*([^\r\n]-)%s*\r?\n") do
    if val ~= want then bad_files[file] = true end
  end

  if runtime == want and next(bad_files) == nil then return false end

  local files = {}
  for f in pairs(bad_files) do table.insert(files, f) end
  table.sort(files)
  if #files == 0 then files = { "/etc/sysctl.conf" } end

  for _, f in ipairs(files) do
    lib.log(lib.set_directive(f, key, want, "="), "Set " .. key .. "=" .. want .. " in " .. f .. " (runtime was " .. (runtime or "?") .. ")")
  end
  return true
end

function M.check_sysctl()
  local changed = false
  changed = check_sysctl_key("net.ipv4.tcp_syncookies", "1") or changed
  changed = check_sysctl_key("net.ipv4.ip_forward", "0") or changed
  if changed then
    lib.log("sysctl --system", "Apply sysctl settings")
  end
end

local SERVICE_PORTS = {
  vsftpd = "21/tcp",
  nginx = "80,443/tcp",
  apache2 = "80,443/tcp",
}

function M.check_firewall()
  if not lib.contains(lib.list_installed_packages(), "ufw") then
    lib.log("apt install -y ufw", "Install package: ufw")
  elseif lib.capture("ufw status 2>/dev/null"):match("Status: active") then
    return
  end

  local readme = lib.read_readme()
  if lib.file_exists("/etc/ssh/sshd_config") then
    lib.log("ufw allow 22/tcp", "Keep SSH reachable before enabling the firewall")
  end
  for service, ports in pairs(SERVICE_PORTS) do
    if readme.services and readme.services[service] then
      lib.log("ufw allow " .. ports, "Keep required service reachable: " .. service)
    end
  end

  -- --force: plain `ufw enable` stops to ask "may disrupt ssh connections, proceed?"
  lib.log("ufw --force enable", "Enable firewall")
end

function M.check_guest_login()
  local content = lib.read_file("/etc/lightdm/lightdm.conf")
  if not content then return end

  if content:match("%[Seat:%*%]") then
    if not content:match("allow%-guest%s*=%s*false") then
      lib.log(
        "sed -i '/%[Seat:%*%]/a allow-guest=false' /etc/lightdm/lightdm.conf",
        "Disable guest account under [Seat:*]"
      )
    end
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
