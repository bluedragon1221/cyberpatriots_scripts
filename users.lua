SUDO_GROUP = "sudo"
SECURE_PASSWORD = "CP_2025!"

local lib = require("lib")

function get_cur_users()
  local file = io.open("/etc/passwd", "r")

  local users = {}
  while true do
    local line = file:read("*l")
    if line then
      local pieces = {}
      for item in string.gmatch(line, "[^:]+") do
        table.insert(pieces, item)
      end

      if tonumber(pieces[3]) >= 1000 and pieces[1] ~= "root" and pieces[1] ~= "nobody" then
        table.insert(users, pieces[1])
      end
    else break end
  end

  return users
end

function get_cur_admins()
  local file = io.open("/etc/group", "r")
  local out = file:read("*a")
  local wheel_line = out:match("\n("..SUDO_GROUP..":[^\n]*)\n")
  if wheel_line then
    local pieces = {}
    for item in wheel_line:gmatch("[^:]+") do
      table.insert(pieces, item)
    end

    local admins = {}
    for admin in pieces[4]:gmatch("[^,]+") do
      table.insert(admins, admin)
    end

    return admins
  else
    error("Failed to read wheel line. Incorrect SUDO_GROUP?")
  end
end

function parse_user_data()
  local html_content = lib.read_readme()
  local pre_content = html_content:match("<h2>Authorized Administrators and Users</h2>[%s%S]-<pre>([%s%S]-)</pre>")
  local admin_block, user_block = pre_content:match("<b>Authorized Administrators:</b>(.*)<b>Authorized Users:</b>(.*)")

  local results = {
    admins = {},
    not_admins = {},
    users = {},
  }
  
  for username, password in admin_block:gmatch("%s*([%w_]+)[^\n]*\n%s*password:%s*([^\n]*)\n") do
    table.insert(results.admins, username)
    table.insert(results.users, username)
  end
  
  for username in user_block:gmatch("(%w+)") do
    table.insert(results.not_admins, username)
    table.insert(results.users, username)
  end

  return results
end

local M = {}

function M.debug_users_readme()
  local user_data = parse_user_data()

  print("Admins: ")
  for _, admin in ipairs(user_data.admins) do
    print("  "..admin)
  end

  print("Users: ")
  for _, user in ipairs(user_data.not_admins) do
    print("  "..user)
  end
end

function M.check_users()
  local users = get_cur_users()
  local admins = get_cur_admins()  
  local user_data = parse_user_data()

  for _, user in ipairs(users) do
    if lib.contains(admins, user) and not lib.contains(user_data.admins, user) then
      lib.log("gpasswd -d "..user.." "..SUDO_GROUP, "This user should NOT be an admin: "..user)
    end

    if not lib.contains(admins, user) and lib.contains(user_data.admins, user) then
      lib.log("usermod -aG "..SUDO_GROUP.." "..user, "This user SHOULD be an admin: "..user)
    end

    if not lib.contains(user_data.users, user) then
      lib.log("deluser --remove-home "..user, "This user should not exist: "..user)
    end

    if lib.contains(users, user) and lib.contains(user_data.admins, user) then
      lib.log("printf "..user..":"..SECURE_PASSWORD.." | chpasswd", "Give this user a secure password (if not done already): "..user)
    end
  end
end

return M
