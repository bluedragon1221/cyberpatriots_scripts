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
  local common_password = io.open("/etc/pam.d/common-password", "r")
  if not common_password then return end

  if not lib.contains(lib.list_installed_packages(), "libpam-cracklib") then
    lib.log("apt install -y libpam-cracklib", "Install package: libpam-cracklib")
  end

  for line_nr, line in lib.enumerate(common_password:lines()) do
    if line:match("^password.*pam_unix.so") then
      if not line:match("remember=5") then
        lib.log("sed -Ei '"..line_nr.."s/$/ remember=5/' /etc/pam.d/common-password", "Enforce password reuse policy")
      end

      if not line:match("minlen=8") then
        lib.log("sed -Ei '"..line_nr.."s/$/ minlen=8/' /etc/pam.d/common-password", "Enforce password length policy")
      end

      if line:match("nullok") then
        lib.log("sed -Ei '"..line_nr.."s/nullok//' /etc/pam.d/common-password", "Null passwords don't authenticate")
      end
    end

    if line:match("^password.*pam_cracklib.so") then
      if not line:match("ucredit=-1") then
        lib.log("sed -Ei '"..line_nr.."s/$/ ucredit=-1/' /etc/pam.d/common-password", "Set password complexity: ucredit")
      end

      if not line:match("lcredit=-1") then
        lib.log("sed -Ei '"..line_nr.."s/$/ lcredit=-1/' /etc/pam.d/common-password", "Set password complexity: lcredit")
      end

      if not line:match("dcredit=-1") then
        lib.log("sed -Ei '"..line_nr.."s/$/ dcredit=-1/' /etc/pam.d/common-password", "Set password complexity: dcredit")
      end
    end
  end
  common_password:close()
end

return M
