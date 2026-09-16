local M = {}

local function get_uid()
  local pipe = io.popen("id -u")
  local uid = pipe:read("*n")
  pipe:close()
  return uid
end

function M.escalate_privileges() 
  if get_uid() ~= 0 then
    print("[!] Not running as root. Escalating privileges...")
  
    local script_path = arg[0]
    local status = os.execute("sudo lua " .. script_path)
  
    if status ~= 0 then
      os.execute("pkexec lua " .. script_path)
    end
  
    os.exit(0)
  end
end

return M
