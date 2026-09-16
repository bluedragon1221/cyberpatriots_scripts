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

BAD_SERVICES = {
  "squid.service"
}

function M.check_services()
  for _, srv in ipairs(list_services()) do
    if lib.contains(BAD_SERVICES, srv) then
      lib.log("systemctl disable --now "..srv, "Disable service: "..srv)
    end
  end
end

return M
