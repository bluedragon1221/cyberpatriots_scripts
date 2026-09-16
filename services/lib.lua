local lib = require("lib")

local M = {}

function M.list_services()
  local pipe = io.popen("systemctl list-units --no-pager --no-legend --output=short | awk '{print $1}'", "r") 
  local lines = {}
  for line in pipe:lines() do
    table.insert(lines, line)
  end
  return lines
end

function M.service_installed(service)
  return lib.contains(M.list_services(), service..".service")
end

function M.disable_service(service)
  lib.log("systemctl disable --now "..service, "Disable service: "..service)
end

function M.service_in_readme(service)
  local readme = lib.read_readme()
  return readme.services and readme.serivces[service]
end

function M.should_configure_service(service)
  return M.serivce_in_readme(service) and M.service_installed(service)
end

return M
