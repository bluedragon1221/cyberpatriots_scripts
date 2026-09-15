local lib = require("lib")

local M = {}

local function list_services()
  local pipe = io.popen("systemctl list-units --no-pager --no-legend --output=short | awk '{print $1}'", "r") 
  local lines = {}
  for line in pipe:lines() do
    table.insert(lines, line)
  end
  return lines
end

function disable_service(service)
  if lib.contains(list_services(), service..".service") then
    lib.log("systemctl disable --now "..service, "Disable service: "..service)
  end
end

-- Services

local function check_nginx()
  local readme = lib.read_readme()
  if readme:match("nginx") then
    lib.log(nil, "You must configure nginx")
  else
    if lib.contains(list_services(), "nginx.service") then
      lib.log("systemctl disable --now nginx", "Disable service: nginx")
    end
  end
end

local function check_apache()
  local readme = lib.read_readme()
  if readme:match("apache") then
    lib.log("", "Make sure to secure the apache2 server")
  else
    disable_service("apache2")
  end
end

local function check_ftp()
  local readme = lib.read_readme()
  if readme:match("ftp") then
    -- TODO write checks for:
    -- - Insecure permissions on FTP root directory
    -- - FTP users may log in with SSL
  else
    disable_service("vsftpd")
  end
end

BAD_SERVICES = {
  "squid.service"
}

function M.check_services()
  check_nginx()
  check_apache()
  check_ftp()
  
  for _, srv in ipairs(list_services()) do
    if lib.contains(BAD_SERVICES, srv) then
      lib.log("systemctl disable --now "..srv, "Disable service: "..srv)
    end
  end
end

return M
