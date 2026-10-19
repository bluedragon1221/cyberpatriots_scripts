LOG_LEVEL = "comment" -- "comment", "command", or "none"

local M = {}

function M.read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
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

function M.read_readme()
  local success, readme = pcall(require, "readme")
  if not success or type(readme) ~= "table" then
    lib.log(nil, "readme.lua not found or contains errors")
    os.exit(1)
  end
  return readme
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
    if command then
      if msg then
        file:write(command.." # "..msg.."\n")
      else
        file:write(command.."\n")
      end
      file:close()
    end
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
    if command then
      print(command)
    end
  elseif LOG_LEVEL == "comment" then
    if command then
      print(command.." # "..msg)
    else
      print("# "..msg)
    end
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

function M.file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

-- Quote a string for safe use inside a single-quoted shell argument
function M.shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Run a command, return true if it exited 0
function M.run_ok(cmd)
  local ok = os.execute(cmd)
  return ok == true or ok == 0
end

-- Run a command, return everything it printed
function M.capture(cmd)
  local p = io.popen(cmd, "r")
  if not p then return "" end
  local out = p:read("*a")
  p:close()
  return out or ""
end

-- Build ONE idempotent shell command that makes `key<sep>value` true in a config file:
--   * rewrites every existing (commented or not) `key` line, or
--   * appends the line if the key isn't there at all.
-- sep is the literal separator: " " (sshd/apache style), "=" or " = ".
-- Uses POSIX classes, never line numbers, so it survives other commands rewriting the file first.
function M.set_directive(file, key, value, sep)
  sep = sep or " "
  local key_re = key:gsub("%.", "[.]")
  local sep_re = sep:find("=", 1, true) and "[[:space:]]*=" or "[[:space:]]"
  local match = "^[[:space:]]*#?[[:space:]]*" .. key_re .. sep_re
  local line = key .. sep .. value
  local f = M.shell_quote(file)
  return string.format("grep -qiE %s %s && sed -i --follow-symlinks -E %s %s || echo %s >> %s",
    M.shell_quote(match), f,
    M.shell_quote("s/" .. match .. ".*/" .. line .. "/I"), f,
    M.shell_quote(line), f)
end

return M
