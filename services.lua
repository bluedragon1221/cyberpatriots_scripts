local lib = require("lib")

local M = {}

local function list_services()
  local pipe = io.popen("systemctl list-units --no-pager --no-legend --output=short | awk '{print $1}'", "r") 
  local lines = {}
  for line in pipe:lines() do
    table.insert(lines, line)
  end
  return lines
end

function M.check_nginx()
  local readme = lib.read_readme()
  if readme:match("nginx") then
    lib.log(nil, "You must configure nginx")
  else
    if lib.contains(list_services(), "nginx.service") then
      lib.log("systemctl disable --now nginx", "Disable service: nginx")
    end
  end
end

function disable_service(service)
  if lib.contains(list_services(), service..".service") then
    lib.log("systemctl disable --now "..service, "Disable service: "..service)
  end
end

function M.check_apache()
  local readme = lib.read_readme()
  if readme:match("apache") then
    lib.log("", "Make sure to secure the apache2 server")
  else
    disable_service("apache2")
  end
end

local function audit_sshd_directive(config_text, key, expected_value)
  local current_value = nil
  
  for line in config_text:gmatch("[^\r\n]+") do
    if not line:match("^%s*#") then
      local k, v = line:match("^%s*([%w]+)%s+(%S+)")
      if k and k:lower() == key:lower() then
        current_value = v
      end
    end
  end

  if not current_value or current_value:lower() ~= expected_value:lower() then
    local fix_cmd = "sed -i -E 's/^[#%s]*(" .. key .. ")[%s].*/\\1 " .. expected_value .. "/I' " .. SSHD_CONFIG
    lib.log(fix_cmd, "sshd setting '" .. key .. "' should be '" .. expected_value .. "' (Currently: " .. (current_value or "unset/default") .. ")")
  end
end

function M.check_sshd()
  local config_text = read_file(SSHD_CONFIG)
  if not config_text then
    lib.log("INFO", "OpenSSH server not installed, skipping SSH checks")
    return
  end

  local options = {
    {"PermitRootLogin", "no"},
    {"PermitEmptyPasswords", "no"},
    {"X11Forwarding", "no"},
    {"MaxAuthTries", "4"},
    {"IgnoreRhosts", "yes"},
    {"HostbasedAuthentication", "no"},
    {"ClientAliveInterval", "300"},
    {"ClientAliveCountMax", "3"},
    {"LoginGraceTime", "60"},
    {"PermitUserEnvironment", "no"}
  }

  for _, opt in ipairs(options) do
    audit_sshd_directive(config_text, opt[1], opt[2])
  end

  if config_text:match("[\r\n]%s*Protocol%s+1") or config_text:match("^%s*Protocol%s+1") then
    lib.log("sed -i 's/^Protocol 1/Protocol 2/' " .. SSHD_CONFIG, "SSH Protocol 1 is insecure")
  end

  local pwauth = config_text:match("[\r\n]%s*PasswordAuthentication%s+([%w]+)")
  lib.log("INFO", "sshd PasswordAuthentication is '" .. (pwauth or "default(yes)") .. "'")
end

function M.check_ftp()
  local readme = lib.read_readme()
  if readme:match("ftp") then
    -- TODO write checks for:
    -- - Insecure permissions on FTP root directory
    -- - FTP users may log in with SSL
  else
    disable_service("vsftpd")
  end
end

BAD_SERVICES = {
  "squid.service"
}

function M.check_misc_services()
  for _, srv in ipairs(list_services()) do
    if lib.contains(BAD_SERVICES, srv) then
      lib.log("systemctl disable --now "..srv, "Disable service: "..srv)
    end
  end
end

return M
