LOG_LEVEL = "comment" -- "comment", "command", or "none"

local M = {}

function M.read_readme()
  local file = io.open(os.getenv("HOME").."/readme.aspx")
  if file then
    local contents = file:read("*a")
    file:close()
    return contents
  else
    error("Can't find readme file at ~/readme.aspx")
  end
end

function M.contains(list, value)
  for _, i in ipairs(list) do
    if value == i then
      return true
    end
  end
  return false
end

function write_line_log(command, msg)
  local file = io.open(os.getenv("HOME").."/cp_log.txt", "a")
  if file then
    if msg then
      file:write(command.." # "..msg.."\n")
    else
      file:write(command.."\n")
    end
    file:close()
  else
    error("Failed to open log file")
  end
end

function M.log(command, msg)
  write_line_log(command, msg)
  
  if LOG_LEVEL == "command" then
    print(command)
  elseif LOG_LEVEL == "comment" then
    print(command.." # "..msg)
  end
end

return M
