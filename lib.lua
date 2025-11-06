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


function M.list_installed_packages()
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

function M.read_file_to_lines(f)
  local file = io.open(f, "r")
  if file then
    local lines = {}
    while true do
      local line = file:read("*l")
      if line then table.insert(lines, line) else break end
    end
    file:close()
    return lines
  else
    error("Failed to read file: "..f)
  end
end

return M
