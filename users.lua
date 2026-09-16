local lib = require("lib")

local M = {}

local ADMIN_GROUPS = { "sudo", "wheel", "admin", "adm" }
local SECURE_PASSWORD = "CP_2025!"

local function check_uid_zero()
  local passwd = lib.read_file("/etc/passwd")
  if not passwd then return end

  for line in passwd:gmatch("[^\r\n]+") do
    local user, uid = line:match("^([^:]+):[^:]+:([^:]+):")
    if user and uid and tonumber(uid) == 0 and user ~= "root" then
      lib.log("usermod -u 1001 " .. user, "WARN: Non-root UID 0 account found (backdoor indicator): " .. user)
    end
  end
end

local function check_blank_passwords()
  local shadow = lib.read_file("/etc/shadow")
  if not shadow then return end

  for line in shadow:gmatch("[^\r\n]+") do
    local user, pass = line:match("^([^:]+):[^:]*:([^:]*)")
    if user and pass == "" then
      lib.log("passwd -l " .. user, "WARN: Account has a BLANK password: " .. user)
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

local function load_user_data()
  local success, config = pcall(require, "authorized_users")
  if not success or type(config) ~= "table" then
    lib.log("echo 'WARN'", "Skipping user authorization checks: authorized_users.lua not found or contains errors.")
    return nil
  end

  local results = {
    admins = config.admins or {},
    not_admins = config.users or {},
    users = {}
  }

  for _, user in ipairs(results.admins) do
    table.insert(results.users, user)
  end

  for _, user in ipairs(results.not_admins) do
    table.insert(results.users, user)
  end

  return results
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

local function audit_pwquality()
  local content = lib.read_file("/etc/security/pwquality.conf")
  if not content then
    lib.log("apt install libpam-pwquality", "pam_pwquality is missing; install and configure password complexity")
    return
  end

  local expected = {
    minlen = "12",
    minclass = "3",
    dcredit = "-1",
    ucredit = "-1",
    lcredit = "-1",
    ocredit = "-1"
  }

  for key, target_val in pairs(expected) do
    local cur_val = nil
    for line in content:gmatch("[^\r\n]+") do
      if not line:match("^%s*#") then
        local k, v = line:match("^%s*(%S+)%s*=%s*(%S+)")
        if k == key then cur_val = v end
      end
    end

    if cur_val ~= target_val then
      lib.log("sed -i -E 's/^[#%s]*(" .. key .. ")\\s*=.*/\\1 = " .. target_val .. "/' /etc/security/pwquality.conf",
        "pwquality setting '" .. key .. "' should be " .. target_val .. " (Currently: " .. (cur_val or "unset") .. ")")
    end
  end

  -- Check if pam_pwquality is wired into PAM
  local pam_handle = io.popen("grep -rqs pam_pwquality /etc/pam.d/ 2>/dev/null; echo $?")
  if pam_handle then
    local res = pam_handle:read("*l")
    pam_handle:close()
    if res ~= "0" then
      lib.log("WARN", "pwquality.conf is configured, but pam_pwquality is not enabled in /etc/pam.d/")
    end
  end
end

-- Audit account lockout configurations in /etc/security/faillock.conf
local function audit_faillock()
  local content = lib.read_file("/etc/security/faillock.conf")
  if not content then
    lib.log("WARN", "faillock.conf missing — account lockout policy needs configuration in /etc/pam.d/")
    return
  end

  local expected = {
    deny = "5",
    unlock_time = "1800"
  }

  for key, target_val in pairs(expected) do
    local cur_val = nil
    for line in content:gmatch("[^\r\n]+") do
      if not line:match("^%s*#") then
        local k, v = line:match("^%s*(%S+)%s*=%s*(%S+)")
        if k == key then cur_val = v end
      end
    end

    if cur_val ~= target_val then
      lib.log("sed -i -E 's/^[#%s]*(" .. key .. ")\\s*=.*/\\1 = " .. target_val .. "/' /etc/security/faillock.conf",
        "faillock setting '" .. key .. "' should be " .. target_val .. " (Currently: " .. (cur_val or "unset") .. ")")
    end
  end

  -- Check if pam_faillock is wired into PAM
  local pam_handle = io.popen("grep -rqs pam_faillock /etc/pam.d/ 2>/dev/null; echo $?")
  if pam_handle then
    local res = pam_handle:read("*l")
    pam_handle:close()
    if res ~= "0" then
      lib.log("WARN", "faillock.conf is configured, but pam_faillock is not referenced in /etc/pam.d/")
    end
  end
end

local function check_pam_backdoors()
  local handle = io.popen("grep -rs 'pam_permit' /etc/pam.d/common-auth /etc/pam.d/system-auth 2>/dev/null | grep -v '^#'")
  if handle then
    local output = handle:read("*a")
    handle:close()
    if output and #output > 0 then
      lib.log("echo 'WARN'", "'pam_permit' found in active PAM authentication stack (Backdoor risk!)")
    end
  end
end

local function check_accounts()
  local user_data = load_user_data()
  if not user_data then return end

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
        if not lib.contains(user_data.users, user) then
          lib.log("userdel -r " .. user, "Unauthorized user found: " .. user)
        else
          audit_user_chage(user)

          if lib.contains(user_data.not_admins, user) and cur_admins_set[user] then
            for _, grp in ipairs(cur_admins_map[user] or {}) do
              lib.log("gpasswd -d " .. user .. " " .. grp, "User should NOT be admin in group '" .. grp .. "': " .. user)
            end
          end

          if lib.contains(user_data.admins, user) and not cur_admins_set[user] then
            lib.log("usermod -aG sudo " .. user, "User SHOULD be admin: " .. user)
          end

          lib.log("printf '" .. user .. ":" .. SECURE_PASSWORD .. "' | chpasswd", "Ensure secure password set for: " .. user)
        end
      end
    end
  end
end

function M.check_users()
  check_uid_zero()
  check_blank_passwords()
  -- audit_pwquality()
  -- audit_faillock()
  check_pam_backdoors()
  check_accounts()
end

return M
