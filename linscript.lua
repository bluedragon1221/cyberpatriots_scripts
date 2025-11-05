SUDO_GROUP = "wheel"
SECURE_PASSWORD = "CP_2025!"

local function get_cur_users()
  local file = io.open("/etc/passwd", "r")

  local users = {}
  while true do
    local line = file:read("*l")
    if line then
      local pieces = {}
      for item in string.gmatch(line, "[^:]+") do
        table.insert(pieces, item)
      end

      if tonumber(pieces[3]) >= 1000 and pieces[1] ~= "root" then
        table.insert(users, pieces[1])
      end
    else break end
  end

  return users
end

local function get_cur_admins()
  local file = io.open("/etc/group", "r")
  local out = file:read("*a")
  local wheel_line = out:match("\n("..SUDO_GROUP..":[^\n]*)\n")
  local pieces = {}
  for item in wheel_line:gmatch("[^:]+") do
    table.insert(pieces, item)
  end

  local admins = {}
  for admin in pieces[4]:gmatch("[^,]+") do
    table.insert(admins, admin)
  end

  return admins
end

local function read_readme()
  local file = io.open(os.getenv("HOME").."/readme.aspx")
  if file then
    return file:read("*a")
  else
    error("Can't find readme file at ~/readme.aspx")
  end
end

function parse_user_data(html_content)
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

function contains(list, value)
  for _, i in ipairs(list) do
    if value == i then
      return true
    end
  end
  return false
end

local function main()
  local users = get_cur_users()
  local admins = get_cur_admins()  
  local user_data = parse_user_data(read_readme())

  for _, user in ipairs(users) do
    if contains(admins, user) and not contains(user_data.admins, user) then
      -- print("# This user should NOT be an admin: "..user)
      print("gpasswd -d "..user.." "..SUDO_GROUP)
    end

    if not contains(admins, user) and contains(user_data.admins, user) then
      -- print("# This user SHOULD be an admin:"..user)
      print("usermod -aG "..SUDO_GROUP.." "..user)
    end

    if not contains(user_data.users, users) then
      -- print("# Remove this user: "..user)
      print("deluser --remove-home "..user)
    end

    if contains(users, user) and contains(user_data.admins, user) then
      -- print("# Give this user a secure password:"..user)
      print("echo '"..SECURE_PASSWORD.."' | passwd --stdin "..user) end
  end
end

main()
