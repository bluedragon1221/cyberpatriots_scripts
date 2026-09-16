local lib = require("lib")

local M = {}

local VSFTPD_CONF = "/etc/vsftpd.conf"

local function disable_vsftpd()
  lib.log("systemctl stop vsftpd", "Stop vsftpd service")
  lib.log("systemctl disable vsftpd", "Disable vsftpd service on boot")
end

local function audit_vsftpd_conf()
  local content = lib.read_file(VSFTPD_CONF)
  if not content then return end

  local expected = {
    anonymous_enable = "NO",
    local_enable = "YES",
    write_enable = "YES",
    chroot_local_user = "YES",
    allow_writeable_chroot = "NO",
    ssl_enable = "YES",
    force_local_data_ssl = "YES",
    force_local_logins_ssl = "YES",
    ssl_tlsv1 = "YES",
    ssl_sslv2 = "NO",
    ssl_sslv3 = "NO",
    require_ssl_reuse = "NO"
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
      lib.log(
        "sed -i -E 's/^[#%s]*(" .. key .. ")\\s*=.*/\\1=" .. target_val .. "/' " .. VSFTPD_CONF,
        "vsftpd setting '" .. key .. "' should be " .. target_val .. " (Currently: " .. (cur_val or "unset") .. ")"
      )
    end
  end
end

local function check_ftp_root_permissions()
  local ftp_roots = { "/srv/ftp", "/var/ftp" }

  for _, path in ipairs(ftp_roots) do
    local handle = io.popen("stat -c '%a %U' " .. path .. " 2>/dev/null")
    if handle then
      local output = handle:read("*l")
      handle:close()

      if output then
        local perms, owner = output:match("^(%d+)%s+(%S+)")
        if perms and (tonumber(perms, 8) % 10 >= 2 or tonumber(perms, 8) % 100 >= 20) then
          lib.log("chmod 755 " .. path, "Fix insecure permissions on FTP root directory: " .. path)
        end
        if owner and owner ~= "root" then
          lib.log("chown root:root " .. path, "Fix owner on FTP root directory (must be root): " .. path)
        end
      end
    end
  end
end

function M.check_ftp()
  local success, readme = pcall(require, "readme")

  if not success or type(readme) ~= "table" then
    lib.log("echo 'WARN'", "Skipping FTP checks: readme.lua not found or contains errors.")
    return
  end

  local ftp_required = readme.services and readme.services.ftp

  if ftp_required then
    audit_vsftpd_conf()
    check_ftp_root_permissions()
  else
    disable_vsftpd()
  end
end

return M
