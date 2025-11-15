LOG_LEVEL = "comment" -- "comment", "command", or "none"

local M = {}

function M.read_readme()
  local file = io.open(os.getenv("HOME").."/readme.aspx")
  if not file then
    local readme_desktop = io.open(os.getenv("HOME").."/Desktop/README.desktop")
    if not readme_desktop then error("Couldn't read README.desktop. are you on a CyberPatriots virtual machine?") end
   
    local content = readme_desktop:read("*a")
    print(content)
    readme_desktop:close()
    local url = content:match("Exec=xdg%-open%s+\"([^\"]+)\"")
    if not url then error("Couldn't find URL in README.desktop") end

    print("Downloading readme to ~/readme.aspx")
    if M.contains(M.list_installed_packages(), "curl") then
      os.execute("curl -o ~/readme.aspx "..url)
    elseif M.contains(M.list_installed_packages(), "wget") then
      os.execute("wget -O ~/readme.aspx "..url)
    else
      error("No mechanism installed for downloading files. Install wget or curl")
    end
  end

  local file = io.open(os.getenv("HOME").."/readme.aspx")
  local contents = file:read("*a")
  file:close()
  return contents
end

function M.contains(list, value)
  for _, i in ipairs(list) do
    if value == i then
      return true
    end
  end
  return false
end

function M.enumerate(iter)
  local i = 0
  return function()
    local value = iter()
    if value ~= nil then
      i = i + 1
      return i, value
    end
  end
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

function M.iter_installed_packages()
  local pipe = io.popen("dpkg-query -W -f'${Package}\n'", "r")
  return function()
    return pipe:read("*l")
  end
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

function M.clear_log()
  io.open(os.getenv("HOME").."/cp_log.txt", "w"):close()
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
