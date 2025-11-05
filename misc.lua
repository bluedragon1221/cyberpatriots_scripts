local lib = require("lib")

local M = {}

local function list_home_files()
  local pipe = os.popen("find "..os.getenv("HOME"))
  local lines = {}
  while true do
    local line = pipe:read("*l")
    if line then table.insert(lines, line) else break end
  end
  pipe:close()
  return lines
end

function M.check_harmful_files()
  local files = list_home_files()

  for _, file in ipairs(files) do
    if file:matches(".mp3$") then
      lib.log("rm "..file, "Remove harmful file: "..file)
    end
  end
end

return M
