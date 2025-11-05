lib = require("lib")

function list_installed_packages()
  local pipe = io.popen("dpkg-query -W -f'${Package}\n'", "r")
  if not pipe then
    error("Couldn't run dpkg-query")
  end

  local packages = {}
  while true do
    local line = pipe:read("*l")
    if line then
      table.insert(packages, line)
    else break end
  end

  return packages
end

BAD_PROGRAMS = {
  "telnet",
  "netcat", "nc",
  "wireshark",
  "mtr-tiny",
  "ophcrack",
  "aisleriot"
}

local M = {}

function M.check_packages()
  local packages = list_installed_packages()
  for _, package in ipairs(packages) do
    if lib.contains(BAD_PROGRAMS, package) then
      lib.log("apt autoremove -y "..package, "Remove program: "..package)
    end
  end
end

return M
