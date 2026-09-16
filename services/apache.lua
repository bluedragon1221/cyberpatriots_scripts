local lib = require("lib")
local slib = require("services.lib")

local M = {}

local APACHE_CONF = "/etc/apache2/apache2.conf"

local function audit_apache_security_conf()
  local security_conf = "/etc/apache2/conf-available/security.conf"
  local target_file = lib.read_file(security_conf) and security_conf or APACHE_CONF

  local content = lib.read_file(target_file)
  if not content then return end

  local expected = {
    ServerTokens = "Prod",
    ServerSignature = "Off",
    TraceEnable = "Off"
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
      lib.log(
        "sed -i -E 's/^[#%s]*(" .. key .. ")\\s+.*/\\1 " .. target_val .. "/' " .. target_file,
        "Apache setting '" .. key .. "' should be " .. target_val .. " (Currently: " .. (cur_val or "unset") .. ")"
      )
    end
  end
end

local function audit_web_root_permissions()
  local web_roots = { "/var/www", "/var/www/html" }

  for _, path in ipairs(web_roots) do
    local handle = io.popen("stat -c '%a %U:%G' " .. path .. " 2>/dev/null")
    if handle then
      local output = handle:read("*l")
      handle:close()

      if output then
        local perms, owner_group = output:match("^(%d+)%s+(%S+)")
        if perms and tonumber(perms, 8) % 10 >= 2 then
          lib.log("chmod 755 " .. path, "Remove world write access on Apache web root: " .. path)
        end
        if owner_group and not (owner_group == "root:root" or owner_group == "www-data:www-data") then
          lib.log("chown -R www-data:www-data " .. path, "Fix owner/group permissions on web root: " .. path)
        end
      end
    end
  end
end

local function check_directory_indexing()
  local handle = io.popen("grep -rn 'Options.*Indexes' /etc/apache2/ 2>/dev/null | grep -v '^-' | grep -v '#'")
  if handle then
    local output = handle:read("*a")
    handle:close()

    if output and output:match("%+Indexes") then
      lib.log(
        "sed -i -E 's/\\+Indexes/-Indexes/g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf 2>/dev/null",
        "Disable directory indexing (+Indexes found in configuration)"
      )
    end
  end
end

function M.check_apache()
  if slib.should_configure_service("apache2") then
    audit_apache_security_conf()
    audit_web_root_permissions()
    check_directory_indexing()
  else
    slib.disable_service("apache2")
  end
end

return M
