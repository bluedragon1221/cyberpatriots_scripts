local lib = require("lib")

local M = {}

local MIN_PASSWORD_LENGTH = 12
local LOCKOUT_DENY = 5
local LOCKOUT_UNLOCK_SECONDS = 900

function M.check_login_defs()
  local content = lib.read_file("/etc/login.defs")
  if not content then return end

  local expected = {
    PASS_MAX_DAYS = "90",
    PASS_MIN_DAYS = "10",
    PASS_WARN_AGE = "7"
  }

  for key, target_val in pairs(expected) do
    local cur_val = nil
    for line in content:gmatch("[^\r\n]+") do
      if not line:match("^%s*#") then
        local k, v = line:match("^%s*(%S+)%s+(%S+)")
        if k == key then cur_val = v end
      end
    end

    if cur_val ~= target_val then
      lib.log("sed -i -E 's/^#?\\s*(" .. key .. ")\\s+.*/\\1\\t" .. target_val .. "/' /etc/login.defs", 
        "login.defs setting '" .. key .. "' should be " .. target_val .. " (Currently: " .. (cur_val or "unset") .. ")")
    end
  end
end

function M.check_common_password()
  if not lib.contains(lib.list_installed_packages(), "libpam-cracklib") then
    lib.log("apt install -y libpam-cracklib", "Install package: libpam-cracklib")
  end

  local content = lib.read_file("/etc/pam.d/common-password")
  if not content then return end

  local file = "/etc/pam.d/common-password"
  local unix_sel = "/^password[[:space:]].*pam_unix[.]so/"

  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    if not line:match("^%s*#") then

      if line:match("^password%s+.*pam_unix%.so") then
        if not line:match("%sremember=%d+") then
          lib.log("sed -i -E '" .. unix_sel .. " s/$/ remember=5/' " .. file, "Enforce password reuse policy")
        end

        local cur = line:match("%sminlen=(%d+)")
        if not cur or tonumber(cur) < MIN_PASSWORD_LENGTH then
          lib.log("sed -i -E '" .. unix_sel .. " { s/[[:space:]]minlen=[0-9]+//; s/$/ minlen=" .. MIN_PASSWORD_LENGTH .. "/ }' " .. file,
            "Enforce minimum password length (" .. MIN_PASSWORD_LENGTH .. ") (Currently: " .. (cur or "unset") .. ")")
        end

        if line:match("%snullok") then
          lib.log("sed -i -E '" .. unix_sel .. " s/[[:space:]]+nullok(_secure)?//' " .. file, "Null passwords don't authenticate")
        end
      end

      if line:match("^password%s+.*pam_cracklib%.so") then
        for _, opt in ipairs({ "ucredit=-1", "lcredit=-1", "dcredit=-1" }) do
          local key = opt:match("^([^=]+)")
          if not line:match("%s" .. key .. "=%-?%d+") then
            lib.log("sed -i -E '/^password[[:space:]].*pam_cracklib[.]so/ s/$/ " .. opt .. "/' " .. file, "Set password complexity: " .. key)
          end
        end
      end
    end
  end
end

function M.check_common_auth()
  local content = lib.read_file("/etc/pam.d/common-auth")
  if not content then return end

  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    if not line:match("^%s*#") and line:match("^auth%s+.*pam_unix%.so") and line:match("%snullok") then
      lib.log("sed -i -E '/^auth[[:space:]].*pam_unix[.]so/ s/[[:space:]]+nullok(_secure)?//' /etc/pam.d/common-auth",
        "Null passwords don't authenticate (remove nullok from common-auth)")
      return
    end
  end
end

function M.check_lockout()
  local auth = lib.read_file("/etc/pam.d/common-auth") or ""
  if auth:match("pam_faillock%.so") then return end

  local dir = "/usr/share/pam-configs/"
  lib.log("printf 'Name: Lockout on failed logins\\nDefault: no\\nPriority: 0\\nAuth-Type: Primary\\nAuth:\\n\\t[default=die]\\t\\t\\tpam_faillock.so authfail\\n' > " .. dir .. "faillock",
    "pam-configs profile: lock out on failed logins")
  lib.log("printf 'Name: Reset lockout on success\\nDefault: no\\nPriority: 0\\nAuth-Type: Additional\\nAuth:\\n\\trequired\\t\\t\\tpam_faillock.so authsucc\\n' > " .. dir .. "faillock_reset",
    "pam-configs profile: reset lockout on success")
  lib.log("printf 'Name: Notify on account lockout\\nDefault: no\\nPriority: 1024\\nAuth-Type: Primary\\nAuth:\\n\\trequisite\\t\\t\\tpam_faillock.so preauth\\n' > " .. dir .. "faillock_notify",
    "pam-configs profile: notify on lockout")
  lib.log("DEBIAN_FRONTEND=noninteractive pam-auth-update --force --enable faillock_notify faillock faillock_reset",
    "Enable the lockout profiles (non-interactive version of the pam-auth-update menu)")

  lib.log(lib.set_directive("/etc/security/faillock.conf", "deny", tostring(LOCKOUT_DENY), " = "),
    "Lock account after " .. LOCKOUT_DENY .. " failed logins")
  lib.log(lib.set_directive("/etc/security/faillock.conf", "unlock_time", tostring(LOCKOUT_UNLOCK_SECONDS), " = "),
    "Unlock after " .. LOCKOUT_UNLOCK_SECONDS .. "s")
end

return M
