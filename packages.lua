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
  -- HACKING TOOLS
  "john",
  "hydra",
  "aircrack",
  "nmap",
  "zenmap",
  "wireshark",
  "tshark",
  "netcat-traditional",
  "ncat",
  "nikto",
  "medusa",
  "ophcrack",
  "hashcat",
  "kismet",
  "ettercap",
  "dsniff",
  "crack",
  "metasploit",
  "yersinia",
  "telnet",
  "netcat", "nc",
  "doona",
  "xprobe",
  "pyrdp",

  -- GAMES
  "aisleriot",
  "gnome-mahjongg",
  "gnome-mines",
  "gnome-sudoku",
  "wesnoth",
  "minetest",
  "supertux",
  "extremetuxracer",
  "0ad",
  "freeciv",
  "zangband",

  -- OTHER
  "amule"
}

local M = {}

local function check_packages()
  local installed = list_installed_packages()
  local to_remove = {}

  for _, package in ipairs(BAD_PROGRAMS) do
    if lib.contains(installed, package) then
      table.insert(to_remove, package)
    end
  end

  if #to_remove > 0 then
    local package_list = table.concat(to_remove, " ")
    lib.log("apt purge -y " .. package_list, "Remove prohibited programs: " .. package_list)
  end
end

local function check_linuxmint_mirror()
  for line_nr, line in lib.enumerate(io.lines("/etc/apt/sources.list.d/official-package-repositories.list")) do
    if line:match("^#deb%s+http://packages.linuxmint.com") then
      lib.log("sed -i '"..line_nr.."s/^#//' /etc/apt/sources.list.d/official-package-repositories.list", "Fix Linux Mint Mirror")
    end
  end
end

local function update_packages()
  lib.log("sudo apt update && sudo apt full-upgrade -y", "Update the system")
end

function M.check_packages()
  check_packages()
  check_linuxmint_mirror()
  update_packages()
end

return M
