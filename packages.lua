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

function M.check_packages()
  local packages = list_installed_packages()
  for _, package in ipairs(packages) do
    if lib.contains(BAD_PROGRAMS, package) then
      lib.log("apt purge -y "..package, "Remove program: "..package)
    end
  end
end

function M.check_linuxmint_mirror()
  for line_nr, line in lib.enumerate(io.lines("/etc/apt/sources.list.d/official-package-repositories.list")) do
    if line:match("^#deb%s+http://packages.linuxmint.com") then
      lib.log("sed -i '"..line_nr.."s/^#//' /etc/apt/sources.list.d/official-package-repositories.list", "Fix Linux Mint Mirror")
    end
  end
end

function M.update_packages()
  lib.log("sudo apt update && sudo apt full-upgrade -y", "Update the system")
end

return M
