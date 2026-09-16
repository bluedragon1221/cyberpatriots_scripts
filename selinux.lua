local lib = require("lib")

local M = {}

local function check_apparmor()
  local aa_pipe = io.popen("command -v aa-status 2>/dev/null && aa-status --enabled 2>/dev/null; echo $?")
  if aa_pipe then
    local res = aa_pipe:read("*l")
    aa_pipe:close()
    if res == "0" then
      lib.log("systemctl enable --now apparmor", "Ensure AppArmor service is enabled and running")
    end
  end
end

local function check_selinux()
  local se_pipe = io.popen("command -v getenforce 2>/dev/null")
  if se_pipe then
    local se_path = se_pipe:read("*l")
    se_pipe:close()

    if se_path and #se_path > 0 then
      local status_pipe = io.popen("getenforce 2>/dev/null")
      if status_pipe then
        local mode = status_pipe:read("*l")
        status_pipe:close()

        if mode and mode ~= "Enforcing" then
          lib.log("setenforce 1", "Set SELinux current mode to Enforcing (Was: " .. mode .. ")")
          lib.log("sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config", "Set persistent SELinux policy to enforcing")
        end
      end
    end
  end
end

local function check_auditd()
  local audit_pipe = io.popen("command -v auditctl 2>/dev/null")
  if audit_pipe then
    local audit_path = audit_pipe:read("*l")
    audit_pipe:close()

    if audit_path and #audit_path > 0 then
      lib.log("systemctl enable --now auditd", "Ensure auditd system auditing service is running")
    end
  end
end

function M.check_security_frameworks()
  check_apparmor()
  check_selinux()
  check_auditd()
end

return M
