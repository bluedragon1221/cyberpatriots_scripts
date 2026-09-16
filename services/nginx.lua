local lib = require("lib")
local slib = require("services.lib")

local NGINX_CONF = "/etc/nginx/nginx.conf"

local function audit_nginx_conf()
  local content = lib.read_file(NGINX_CONF)
  if not content then return end

  if not content:match("server_tokens%s+off%s*;") then
    if content:match("server_tokens") then
      lib.log("sed -i -E 's/server_tokens\\s+on\\s*;/server_tokens off;/' " .. NGINX_CONF, "Disable Nginx server_tokens (hide version)")
    else
      lib.log("sed -i '/http {/a \\    server_tokens off;' " .. NGINX_CONF, "Add server_tokens off to Nginx http block")
    end
  end
end

local function audit_nginx_ssl()
  local content = lib.read_file(NGINX_CONF)
  if not content then return end

  local handle = io.popen("grep -rn 'ssl_protocols' /etc/nginx/ 2>/dev/null | grep -v '#'")
  if handle then
    local output = handle:read("*a")
    handle:close()

    if output:match("TLSv1%.[01]") or output:match("SSLv") then
      lib.log(
        "sed -i -E 's/ssl_protocols.*/ssl_protocols TLSv1.2 TLSv1.3;/g' /etc/nginx/nginx.conf /etc/nginx/conf.d/*.conf /etc/nginx/sites-enabled/* 2>/dev/null",
        "Enforce secure SSL protocols (TLSv1.2 and TLSv1.3 only)"
      )
    end
  end
end

local function audit_web_root_permissions()
  local web_roots = { "/var/www", "/usr/share/nginx/html", "/var/www/html" }

  for _, path in ipairs(web_roots) do
    local handle = io.popen("stat -c '%a %U:%G' " .. path .. " 2>/dev/null")
    if handle then
      local output = handle:read("*l")
      handle:close()

      if output then
        local perms, owner_group = output:match("^(%d+)%s+(%S+)")
        if perms and tonumber(perms, 8) % 10 >= 2 then
          lib.log("chmod 755 " .. path, "Remove world write access on Nginx web root: " .. path)
        end
        if owner_group and not (owner_group == "root:root" or owner_group == "www-data:www-data") then
          lib.log("chown -R www-data:www-data " .. path, "Fix owner/group permissions on Nginx web root: " .. path)
        end
      end
    end
  end
end

local function check_directory_indexing()
  local handle = io.popen("grep -rn 'autoindex%s*on' /etc/nginx/ 2>/dev/null | grep -v '#'")
  if handle then
    local output = handle:read("*a")
    handle:close()

    if output and #output > 0 then
      lib.log(
        "sed -i -E 's/autoindex\\s+on\\s*;/autoindex off;/g' /etc/nginx/nginx.conf /etc/nginx/conf.d/*.conf /etc/nginx/sites-enabled/* 2>/dev/null",
        "Disable Nginx directory autoindexing"
      )
    end
  end
end

return {
  check_nginx = function()
    if slib.should_configure_service("nginx") then
      audit_nginx_conf()
      audit_nginx_ssl()
      audit_web_root_permissions()
      check_directory_indexing()
    else
      slib.disable_service("nginx")
    end
  end
}
