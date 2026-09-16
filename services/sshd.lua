local lib = require("lib")
local slib = require("services.lib")

SSHD_CONFIG = "/etc/ssh/sshd_config"

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

SSHD_OPTIONS = {
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

local M = {}

function M.check_sshd()
  if slib.service_installed("sshd") then
    local config_text = lib.read_file(SSHD_CONFIG)
    if not config_text then
      lib.log(nil, "Can't find sshd config file, skipping ssh checks")
      return
    end

    for _, opt in ipairs(SSHD_OPTIONS) do
      audit_sshd_directive(config_text, opt[1], opt[2])
    end

    if config_text:match("[\r\n]%s*Protocol%s+1") or config_text:match("^%s*Protocol%s+1") then
      lib.log("sed -i 's/^Protocol 1/Protocol 2/' " .. SSHD_CONFIG, "SSH Protocol 1 is insecure")
    end

    local pwauth = config_text:match("[\r\n]%s*PasswordAuthentication%s+([%w]+)")
    lib.log(nil, "sshd PasswordAuthentication is '" .. (pwauth or "default(yes)") .. "'")
  end
end

return M
