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
  "doona",
  "xprobe",
  "pyrdp",
  "aisleriot",
  "amule",
  "zangband"
}

local M = {}

function M.check_packages()
  local packages = list_installed_packages()
  for _, package in ipairs(packages) do
    if lib.contains(BAD_PROGRAMS, package) then
      lib.log("apt purge -y "..package, "Remove program: "..package)
    end
  end
end

function M.update_packages()
  lib.log("sudo apt update && sudo apt full-upgrade -y", "Update the system")
end

return M
