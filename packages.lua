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
  "aircrack-ng",
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
  local readme = lib.read_readme()
  local allowed = readme.software or {}
  local to_remove = {}

  for _, package in ipairs(BAD_PROGRAMS) do
    -- the README can require "hacking" tools (the training image lists wireshark + ophcrack)
    if lib.contains(installed, package) and not lib.contains(allowed, package) then
      table.insert(to_remove, package)
    end
  end

  if #to_remove > 0 then
    local package_list = table.concat(to_remove, " ")
    lib.log("apt purge -y " .. package_list, "Remove prohibited programs: " .. package_list)
  end
end

-- Hosts that belong in a stock Linux Mint sources file
local KNOWN_REPO_HOSTS = { "packages%.linuxmint%.com", "archive%.ubuntu%.com", "security%.ubuntu%.com" }
local MINT_SOURCES = "/etc/apt/sources.list.d/official-package-repositories.list"

local function check_linuxmint_mirror()
  if not lib.file_exists(MINT_SOURCES) then return end  -- not Mint
  for line_nr, line in lib.enumerate(io.lines(MINT_SOURCES)) do
    for _, host in ipairs(KNOWN_REPO_HOSTS) do
      if line:match("^#%s*deb%s+https?://" .. host) then
        lib.log("sed -i '" .. line_nr .. "s/^#\\s*//' " .. MINT_SOURCES, "Re-enable disabled repository line " .. line_nr .. " (" .. host:gsub("%%", "") .. ")")
      end
    end
  end
end

function M.fix_sources()
  check_linuxmint_mirror()
  lib.log("apt-get update", "Refresh package lists")
end

local function update_packages()
  lib.log("DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold full-upgrade",
    "Update the system (fixes vsftpd etc.)")
end

function M.check_packages()
  check_packages()
  update_packages()
end

return M
