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
  local handle = io.popen("chage -l " .. username .. " 2>/dev/null")
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

local function check_accounts()
  local readme = lib.read_readme()

  local cur_admins_set, cur_admins_map = get_cur_admins()
  local passwd_content = lib.read_file("/etc/passwd")
  if not passwd_content then return end

  for line in passwd_content:gmatch("[^\r\n]+") do
    local user, uid, shell = line:match("^([^:]+):[^:]+:([^:]+):[^:]*:[^:]*:[^:]*:([^:]*)")
    local uid_num = tonumber(uid)

    if user and uid_num then
      if uid_num < 1000 and uid_num > 0 then
        if shell and shell:match("/bin/[bsh|sh|zsh|bash]") then
          lib.log("usermod -s /usr/sbin/nologin " .. user, "System account has active login shell: " .. user)
        end
      end

      if uid_num >= 1000 and user ~= "nobody" then
        local is_authorized_admin = lib.contains(readme.admins, user)
        local is_authorized_user = lib.contains(readme.users, user)

        if not is_authorized_admin and not is_authorized_user then
          lib.log("userdel -r " .. user, "Unauthorized user found: " .. user)
        else
          -- audit_user_chage(user)

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

function M.check_users()
  check_uid_zero()
  check_blank_passwords()
  check_pam_backdoors()
  check_accounts()
end

return M
