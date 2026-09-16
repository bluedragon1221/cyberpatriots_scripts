local lib = require("lib")

local M = {}

function M.check_cron()
  for i, line in lib.enumerate(io.lines("/etc/crontab")) do
    local words = {}
    local cmd = line:match("^%s*%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+(.+)$")
    if cmd then
        -- netcat backdoor
        if cmd:match("/usr/bin/nc.traditional") then
          lib.log("sed -i '"..i.."d' /etc/crontab", "Delete suspicious netcat backdoor in crontab: line "..i)
        end

        -- suspicious python script
        if cmd:match("python3") then
          lib.log("sed -i '"..i.."d' /etc/crontab", "Delete suspicious python script in crontab: line "..i)
        end
      end
    end
end

return M
