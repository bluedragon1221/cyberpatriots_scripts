local M = {}

local function get_uid()
  local pipe = io.popen("id -u")
  local uid = pipe:read("*n")
  pipe:close()
  return uid
end

function M.escalate_privileges() 
  if get_uid() ~= 0 then
    print("[!] Not running as root. Rerun with sudo")
    os.exit(1)
  end
end

return M
