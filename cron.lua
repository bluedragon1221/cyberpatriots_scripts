local lib = require("lib")

local M = {}

local function log_kill_processes(cmd)
  local quoted = cmd:gsub("'", "'\\''")
  local f = io.popen("pgrep -af '"..quoted.."'")

  local pids = {}
  for line in f:lines() do
    local pid, full = line:match("^(%d+)%s+(.+)$")
    if pid then
      table.insert(pids, pid)
      lib.log("kill "..pid, "Kill suspicious process: pid "..pid)
    end
  end
  f:close()
end

function M.check_cron()
  for i, line in lib.enumerate(io.lines("/etc/crontab")) do
    local words = {}
    local cmd = line:match("^%s*%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+(.+)$")
    if cmd then
        -- netcat backdoor
        if cmd:match("/usr/bin/nc.traditional") then
          lib.log("sed -i '"..i.."d' /etc/crontab", "Delete suspicious netcat backdoor in crontab: line "..i)
          log_kill_processes(cmd)
        end

        -- suspicious python script
        if cmd:match("python3") then
          lib.log("sed -i '"..i.."d' /etc/crontab", "Delete suspicious python script in crontab: line "..i)
          log_kill_processes(cmd)
        end
      end
    end
end

M.check_cron()

return M
