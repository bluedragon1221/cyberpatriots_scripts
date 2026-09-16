local lib = require("lib")

local M = {}

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

  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  for line_nr, line in ipairs(lines) do
    if not line:match("^%s*#") then
      
      if line:match("^password%s+.*pam_unix%.so") then
        if not line:match("%sremember=%d+") then
          lib.log(string.format("sed -i '%ds/$/ remember=5/' /etc/pam.d/common-password", line_nr), "Enforce password reuse policy")
        end

        if not line:match("%sminlen=%d+") then
          lib.log(string.format("sed -i '%ds/$/ minlen=8/' /etc/pam.d/common-password", line_nr), "Enforce password length policy")
        end

        if line:match("%snullok") then
          lib.log(string.format("sed -i '%ds/\\bnullok\\b//' /etc/pam.d/common-password", line_nr), "Null passwords don't authenticate")
        end
      end

      if line:match("^password%s+.*pam_cracklib%.so") then
        for _, opt in ipairs({ "ucredit=-1", "lcredit=-1", "dcredit=-1" }) do
          local key = opt:match("^([^=]+)")
          if not line:match("%s" .. key .. "=%-?%d+") then
            lib.log(string.format("sed -i '%ds/$/ %s/' /etc/pam.d/common-password", line_nr, opt), "Set password complexity: " .. key)
          end
        end
      end
    end
  end
end

return M
