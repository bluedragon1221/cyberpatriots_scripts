local lib = require("lib")

local M = {}

-- Interpreters / netcat-likes that have no business owning a listening socket on a stock desktop.
local INTERPRETERS = {
  python = true, python2 = true, python3 = true,
  perl = true, ruby = true, php = true, lua = true, node = true,
  nc = true, ncat = true, netcat = true, socat = true, ["nc.traditional"] = true,
}
local SCRIPT_INTERPRETERS = { python = true, python2 = true, python3 = true, perl = true, ruby = true, php = true, lua = true, node = true }

local function read_cmdline(pid)
  local raw = lib.read_file("/proc/" .. pid .. "/cmdline")
  local args = {}
  if raw then
    for arg in raw:gmatch("([^\0]+)") do table.insert(args, arg) end
  end
  return args
end

local function absolute(path, pid)
  if path:sub(1, 1) == "/" then return path end
  local cwd = lib.capture("readlink /proc/" .. pid .. "/cwd 2>/dev/null"):gsub("%s+$", "")
  if cwd == "" then return path end
  return (cwd .. "/" .. path):gsub("/%./", "/")
end

local function dirname(path)
  return path:match("^(.*)/[^/]+$") or "."
end

-- Anything referencing the script from cron / systemd / rc.local would respawn it.
local function find_persistence(script)
  local found = lib.capture("grep -rIsl -F -- " .. lib.shell_quote(script) ..
    " /etc/cron* /var/spool/cron /etc/systemd /etc/init.d /etc/rc.local /etc/profile.d 2>/dev/null")
  for file in found:gmatch("[^\r\n]+") do
    lib.log(nil, "PERSISTENCE: " .. file .. " references " .. script .. " (remove that entry too)")
  end
end

function M.check_listening_backdoors()
  local out = lib.capture("ss -H -tulnp 2>/dev/null")
  local seen = {}

  for line in out:gmatch("[^\r\n]+") do
    local fields = {}
    for f in line:gmatch("%S+") do table.insert(fields, f) end
    local port = fields[5] and fields[5]:match(":(%d+)$")  -- Netid State Recv-Q Send-Q Local Peer Process
    for name, pid in line:gmatch('%(%("([^"]+)",pid=(%d+)') do
      if INTERPRETERS[name] and not seen[pid] then
        seen[pid] = true

        local args = read_cmdline(pid)
        local script
        if SCRIPT_INTERPRETERS[name] then
          for i = 2, #args do
            if args[i]:sub(1, 1) ~= "-" then script = absolute(args[i], pid) break end
          end
        end

        local owned = script and lib.run_ok("dpkg -S " .. lib.shell_quote(script) .. " >/dev/null 2>&1")
        local where = "port " .. (port or "?") .. ", pid " .. pid .. ", cmd: " .. table.concat(args, " ")

        if script and owned then
          lib.log(nil, "REVIEW: " .. name .. " listener is a packaged script (" .. script .. "), " .. where)
        elseif script then
          lib.log("pkill -f " .. lib.shell_quote(script), "Stop backdoor listening on " .. where)
          lib.log("rm -f " .. lib.shell_quote(script), "Remove backdoor script")
          lib.log(nil, "FORENSICS HINT: absolute path of the directory containing the backdoor: " .. dirname(script))
          find_persistence(script)
        else
          lib.log("kill " .. pid, "Stop " .. name .. " listener (" .. where .. ")")
        end
      end
    end
  end
end

return M
