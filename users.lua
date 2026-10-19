local lib = require("lib")

local M = {}

local ADMIN_GROUPS = { "sudo", "wheel", "admin", "adm" }
local SECURE_PASSWORD = "Cyber_2026!"
local PREDETERMINED_SALT = "CyberSalt2026"

-- Helper function to generate SHA-512 shadow hash using a fixed salt via OpenSSL
local function generate_target_hash(password, salt)
  local handle = io.popen(string.format("openssl passwd -6 -salt %q %q 2>/dev/null", salt, password))
  if not handle then return nil end
  local hash = handle:read("*l")
  handle:close()
  return hash
end

-- Pre-calculate target hash using predetermined salt
local TARGET_HASH = generate_target_hash(SECURE_PASSWORD, PREDETERMINED_SALT)

local function check_uid_zero()
  local passwd = lib.read_file("/etc/passwd")
  if not passwd then return end

  for line in passwd:gmatch("[^\r\n]+") do
    local user, uid = line:match("^([^:]+):[^:]+:([^:]+):")
    if user and uid and tonumber(uid) == 0 and user ~= "root" then
      lib.log("usermod -u 1001 " .. user, "Non-root UID 0 account found (backdoor indicator): " .. user)
    end
  end
end

local function check_blank_passwords()
  local shadow = lib.read_file("/etc/shadow")
  if not shadow then return end

  for line in shadow:gmatch("[^\r\n]+") do
    local user, pass = line:match("^([^:]+):([^:]*):")
    if user and pass == "" then
      lib.log("passwd -l " .. user, "Account has a BLANK password: " .. user)
    end
  end
end

local function get_cur_admins()
  local group_content = lib.read_file("/etc/group")
  if not group_content then return {}, {} end

  local admin_map = {}
  local admin_set = {}

  for line in group_content:gmatch("[^\r\n]+") do
    local group_name, _, _, members_str = line:match("^([^:]+):([^:]*):([^:]*):([^:]*)")
    if group_name and members_str then
      for _, g in ipairs(ADMIN_GROUPS) do
        if group_name == g then
          for member in members_str:gmatch("[^,]+") do
            member = member:match("^%s*(.-)%s*$")
            if #member > 0 then
              admin_map[member] = admin_map[member] or {}
              table.insert(admin_map[member], group_name)
              admin_set[member] = true
            end
          end
        end
      end
    end
  end

  return admin_set, admin_map
end

local function is_password_already_set(username, target_hash)
  if not target_hash then return false end
  local shadow_content = lib.read_file("/etc/shadow")
  if not shadow_content then return false end

  for line in shadow_content:gmatch("[^\r\n]+") do
    local user, hash = line:match("^([^:]+):([^:]+):")
    if user == username and hash then
      if hash == target_hash then
        return true
      end
    end
  end

  return false
end

local function audit_user_chage(username)
  local handle = io.popen("LC_ALL=C chage -l " .. username .. " 2>/dev/null")
  if not handle then return end
  local output = handle:read("*a")
  handle:close()

  local max_days = output:match("Maximum number of days between password change%s*:%s*(%d+)")
  if max_days and max_days ~= "90" then
    lib.log("chage -M 90 -m 10 -W 7 " .. username, "Apply password aging (max=90, min=10, warn=7) for user: " .. username)
  end
end

local function check_pam_backdoors()
  local handle = io.popen("grep -Hrs 'pam_permit' /etc/pam.d/common-auth /etc/pam.d/system-auth 2>/dev/null | grep -v '^[^\\:]*:#'")
  if handle then
    local output = handle:read("*a")
    handle:close()

    if output and #output > 0 then
      for line in output:gmatch("[^\r\n]+") do
        local file, match = line:match("^([^:]+):%s*(.*)")
        if file and match then
          lib.log(nil, string.format("'pam_permit' found in '%s' (Backdoor risk! Line: %s)", file, match))
        end
      end
    end
  end
end

local LOGIN_SHELLS = { bash=true, sh=true, dash=true, zsh=true, ksh=true, fish=true, tcsh=true, csh=true, rbash=true }

local KNOWN_SYSTEM_ACCOUNTS = { postgres=true, syslog=true }

local function check_hidden_user(user, shell, home, readme)
  if lib.contains(readme.admins, user) or lib.contains(readme.users, user) then return end
  if KNOWN_SYSTEM_ACCOUNTS[user] then return end

  local shell_name = (shell or ""):match("([^/]+)$")
  if shell_name and LOGIN_SHELLS[shell_name] then
    lib.log("userdel -r " .. user, "Hidden unauthorized user (UID < 1000 with login shell " .. shell .. "): " .. user)
  elseif home and home:match("^/home/") then
    lib.log(nil, "REVIEW: UID < 1000 account '" .. user .. "' has home " .. home .. " but no login shell")
  end
end

local function check_accounts()
  local readme = lib.read_readme()
  if #readme.admins == 0 and #readme.users == 0 then
    lib.log(nil, "readme.lua has no admins/users filled in; skipping account checks (would flag EVERY user)")
    return
  end

  local cur_admins_set, cur_admins_map = get_cur_admins()
  local passwd_content = lib.read_file("/etc/passwd")
  if not passwd_content then return end

  for line in passwd_content:gmatch("[^\r\n]+") do
    local user, uid, home, shell = line:match("^([^:]+):[^:]+:([^:]+):[^:]*:[^:]*:([^:]*):([^:]*)")
    local uid_num = tonumber(uid)

    if user and uid_num then
      if uid_num < 1000 and uid_num > 0 then
        check_hidden_user(user, shell, home, readme)
      end

      if uid_num >= 1000 and user ~= "nobody" then
        local is_authorized_admin = lib.contains(readme.admins, user)
        local is_authorized_user = lib.contains(readme.users, user)

        if not is_authorized_admin and not is_authorized_user then
          lib.log("userdel -r " .. user, "Unauthorized user found: " .. user)
        else
          audit_user_chage(user)

          if is_authorized_user and cur_admins_set[user] then
            for _, grp in ipairs(cur_admins_map[user] or {}) do
              lib.log("gpasswd -d " .. user .. " " .. grp, "User should NOT be admin in group '" .. grp .. "': " .. user)
            end
          end

          if is_authorized_admin then
            if not cur_admins_set[user] then
              lib.log("usermod -aG sudo " .. user, "User SHOULD be admin: " .. user)
            end

            if not is_password_already_set(user, TARGET_HASH) then
              lib.log("printf '" .. user .. ":" .. TARGET_HASH .. "' | chpasswd -e", "Ensure secure password set for admin: " .. user)
            end
          end
        end
      end
    end
  end
end


local function check_groups()
  local readme = lib.read_readme()
  if not readme.groups then return end

  local existing = {}
  local content = lib.read_file("/etc/group") or ""
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    local name, members = line:match("^([^:]+):[^:]*:[^:]*:(.*)$")
    if name then
      existing[name] = {}
      for m in members:gmatch("[^,%s]+") do existing[name][m] = true end
    end
  end

  local names = {}
  for name in pairs(readme.groups) do table.insert(names, name) end
  table.sort(names)

  for _, group in ipairs(names) do
    if not existing[group] then
      lib.log("addgroup " .. group, "Create group: " .. group)
    end
    for _, user in ipairs(readme.groups[group]) do
      if not (existing[group] and existing[group][user]) then
        -- -a (append) rather than -M, which would overwrite existing members
        lib.log("gpasswd -a " .. user .. " " .. group, "Add " .. user .. " to group " .. group)
      end
    end
  end
end

function M.check_users()
  check_uid_zero()
  check_blank_passwords()
  check_pam_backdoors()
  check_accounts()
  check_groups()
end

return M
