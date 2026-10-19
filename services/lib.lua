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

-- `systemctl cat` succeeds for any unit file that exists, active or not, and follows aliases
function M.service_installed(service)
  return lib.run_ok("systemctl cat "..service..".service >/dev/null 2>&1")
end

function M.service_running_or_enabled(service)
  return lib.run_ok("systemctl is-active --quiet "..service..".service")
      or lib.run_ok("systemctl is-enabled --quiet "..service..".service")
end

-- Only emits the command if there's something to disable
function M.disable_service(service)
  service = service:gsub("%.service$", "")
  if M.service_running_or_enabled(service) then
    lib.log("systemctl disable --now "..service, "Disable service: "..service)
  end
end

function M.service_in_readme(service)
  local readme = lib.read_readme()
  return readme.services and readme.services[service]
end

function M.should_configure_service(service)
  return M.service_in_readme(service) and M.service_installed(service)
end

return M
