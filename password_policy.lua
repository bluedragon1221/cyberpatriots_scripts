lib = require("lib")

local M = {}

function M.check_login_defs()
  local f = io.open("/etc/login.defs", "r")
  local login_defs = f:read("*a")

  local max_days = login_defs:match("\nPASS_MAX_DAYS%s+(%d+)\n")
  if tonumber(max_days) ~= 90 then
    lib.log("sed -Ei 's/^PASS_MAX_DAYS\\s+[0-9]+$/PASS_MAX_DAYS 90/' /etc/login.defs", "Update password maximum time")
  end

  local min_days = login_defs:match("\nPASS_MIN_DAYS%s+(%d+)\n")
  if tonumber(min_days) ~= 10 then
    lib.log("sed -Ei 's/^PASS_MIN_DAYS\\s+[0-9]+$/PASS_MIN_DAYS 10/' /etc/login.defs", "Update password minimum time")
  end

  local warn_age = login_defs:match("\nPASS_WARN_AGE%s+(%d+)\n")
  if tonumber(warn_age) ~= 7 then
    lib.log("sed -Ei 's/^PASSWORD_WARN_AGE\\s+[0-9]+$/PASS_WARN_AGE 7/' /etc/login.defs", "Update password warn age")
  end
end

function M.check_common_password()
  local common_password = io.open("/etc/pam.d/common-password", "r"):read("*a")

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
      -- ucredit: Uppercase letters (A-Z)
      if not line:match("ucredit=-1") then
        lib.log("sed -Ei '"..line_nr.."s/$/ ucredit=-1/' /etc/pam.d/common-password", "Set password complexity: ucredit")
      end

      -- lcredit: Lowercase letters (a-z)
      if not line:match("lcredit=-1") then
        lib.log("sed -Ei '"..line_nr.."s/$/ lcredit=-1/' /etc/pam.d/common-password", "Set password complexity: lcredit")
      end

      -- dcredit: Digits (0-9)
      if not line:match("dcredit=-1") then
        lib.log("sed -Ei '"..line_nr.."s/$/ dcredit=-1/' /etc/pam.d/common-password", "Set password complexity: dcredit")
      end
  end
end

return M
