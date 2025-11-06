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

function M.check_nginx()
  local readme = lib.read_readme()
  if readme:match("nginx") then
    lib.log(nil, "You must configure nginx")
  else
    if lib.contains(list_services(), "nginx.service") then
      lib.log("systemctl disable --now nginx", "Disable service: nginx")
    end
  end
end

BAD_SERVICES = {
  "squid.service"
}

function M.check_misc_services()
  for _, srv in ipairs(list_services()) do
    if lib.contains(BAD_SERVICES, srv) then
      lib.log("systemctl disable --now "..srv, "Disable service: "..srv)
    end
  end
end

return M
