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
  "aisleriot"
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

function M.check_autoupgrade()
  local apt_cfg = io.open("/etc/apt/apt.conf.d/20auto-upgrades", "r")
  if not apt_cfg then
    lib.log([[cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF]], "Enable automatic upgrades")
  end
end

return M
