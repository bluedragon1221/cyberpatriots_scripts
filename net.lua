local lib = require("lib")

local M = {}

function M.check_network_and_dns()
  local hosts_content = lib.read_file("/etc/hosts")
  if hosts_content then
    local line_nr = 0
    for line in hosts_content:gmatch("[^\r\n]+") do
      line_nr = line_nr + 1
      local clean_line = line:match("^%s*(.-)%s*$")
      
      if clean_line ~= "" and not clean_line:match("^#") then
        if not clean_line:match("^127%.0%.0%.1") and 
           not clean_line:match("^127%.0%.1%.1") and 
           not clean_line:match("^::1") and 
           not clean_line:match("^fe00::0") and 
           not clean_line:match("^ff00::0") and 
           not clean_line:match("^ff02::") then
          lib.log("sed -i '" .. line_nr .. "d' /etc/hosts", "Remove suspicious /etc/hosts entry: " .. clean_line)
        end
      end
    end
  end
end

return M
