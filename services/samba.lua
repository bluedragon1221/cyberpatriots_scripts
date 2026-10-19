local lib = require("lib")
local slib = require("services.lib")

local SMB_CONF = "/etc/samba/smb.conf"

-- Debian/Ubuntu/Mint split Samba into these units (samba-ad-dc is only for domain controllers)
local SAMBA_UNITS = { "smbd", "nmbd" }

-- smb.conf is sectioned, so lib.set_directive (which appends at EOF) would drop new lines into
-- whatever share happens to be last. These helpers edit one named section instead.

local function norm_key(k)
  return (k:lower():gsub("%s+", " "))
end

local function norm_val(v)
  v = v:lower()
  if v == "true" or v == "1" or v == "on" then return "yes" end
  if v == "false" or v == "0" or v == "off" then return "no" end
  return v
end

local function regex_escape(s)
  return (s:gsub("([%]%[%.%*%^%$%\\%/%(%)%+%?%{%}%|])", "\\%1"))
end

-- "guest ok" -> "guest[[:space:]]+ok" (smb.conf treats any run of whitespace in a key as one space)
local function key_regex(key)
  local parts = {}
  for word in key:gmatch("%S+") do table.insert(parts, regex_escape(word)) end
  return table.concat(parts, "[[:space:]]+")
end

-- Delete every active line for any of `keys` inside [section], then add `key = value` right under the header.
-- Pattern based (no line numbers), so it's idempotent and survives other edits to the file.
local function set_in_section(section, keys, value)
  local header = "^[[:space:]]*\\[" .. regex_escape(section) .. "\\][[:space:]]*$"
  local range = "/" .. header .. "/,/^[[:space:]]*\\[/"
  local deletes = {}
  for _, k in ipairs(keys) do
    table.insert(deletes, "/^[[:space:]]*" .. key_regex(k) .. "[[:space:]]*=/Id")
  end
  local f = lib.shell_quote(SMB_CONF)
  local del = "sed -i --follow-symlinks -E " .. lib.shell_quote(range .. "{" .. table.concat(deletes, ";") .. "}") .. " " .. f
  local add = "sed -i --follow-symlinks -E " .. lib.shell_quote("/" .. header .. "/a " .. keys[1] .. " = " .. value) .. " " .. f
  return del .. " && " .. add
end

-- Parse smb.conf -> { section_name = { normalized_key = value } }, plus section order
local function parse_conf(content)
  local sections, order, current = {}, {}, nil
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    local name = line:match("^%s*%[(.-)%]%s*$")
    if name then
      current = name:lower()
      if not sections[current] then
        sections[current] = { __name = name }
        table.insert(order, current)
      end
    elseif current and not line:match("^%s*[#;]") then
      local k, v = line:match("^%s*([^=]-)%s*=%s*(.-)%s*$")
      if k and k ~= "" then sections[current][norm_key(k)] = v end
    end
  end
  return sections, order
end

local function proto_ok(v)
  v = v:upper()
  return v:match("^SMB[23]") ~= nil
end

-- name = canonical key (first of `keys` is what gets written)
local GLOBAL_SETTINGS = {
  { keys = { "restrict anonymous" },     want = "2",            ok = function(v) return v == "2" end },
  { keys = { "map to guest" },           want = "never",        ok = function(v) return v == "never" end },
  { keys = { "server min protocol", "min protocol" }, want = "SMB2", ok = proto_ok },  -- no SMB1/NT1
  { keys = { "ntlm auth" },              want = "ntlmv2-only",  ok = function(v) return v == "ntlmv2-only" or v == "mschapv2-and-ntlmv2-only" end },
  { keys = { "server signing" },         want = "mandatory",    ok = function(v) return v == "mandatory" or v == "required" end },
  { keys = { "lanman auth" },            want = "no",           ok = function(v) return v == "no" end },
  { keys = { "null passwords" },         want = "no",           ok = function(v) return v == "no" end },
  { keys = { "usershare allow guests" }, want = "no",           ok = function(v) return v == "no" end },
}

local function current(section, keys)
  for _, k in ipairs(keys) do
    local v = section and section[norm_key(k)]
    if v then return v end
  end
  return nil
end

local function audit_global(sections)
  local changed = false
  local g = sections["global"]
  if not g then
    lib.log(nil, "smb.conf has no [global] section, skipping global hardening")
    return false
  end

  for _, s in ipairs(GLOBAL_SETTINGS) do
    local cur = current(g, s.keys)
    local val = cur and norm_val(cur)
    if not val or not s.ok(val) then
      lib.log(set_in_section("global", s.keys, s.want),
        "samba [global] '" .. s.keys[1] .. "' should be " .. s.want .. " (Currently: " .. (cur or "unset") .. ")")
      changed = true
    end
  end
  return changed
end

local SPECIAL_SECTIONS = { global = true, printers = true, ["print$"] = true }

local function audit_shares(sections, order)
  local changed = false
  for _, key in ipairs(order) do
    local sec = sections[key]
    if not SPECIAL_SECTIONS[key] then
      local guest = current(sec, { "guest ok", "public" })
      if guest and norm_val(guest) == "yes" then
        lib.log(set_in_section(sec.__name, { "guest ok", "public" }, "no"),
          "samba share [" .. sec.__name .. "] allows guests, set 'guest ok = no'")
        changed = true
      end

      local ro = current(sec, { "read only" })
      local wr = current(sec, { "writable", "writeable", "write ok" })
      if (ro and norm_val(ro) == "no") or (wr and norm_val(wr) == "yes") then
        lib.log(nil, "REVIEW: samba share [" .. sec.__name .. "] is writable; make sure the README requires that")
      end
    end
  end
  return changed
end

-- Samba keeps its own password database; accounts in it that the README doesn't list can still log in over SMB.
local function audit_samba_users()
  local readme = lib.read_readme()
  if #readme.admins == 0 and #readme.users == 0 then return end

  for line in lib.capture("pdbedit -L 2>/dev/null"):gmatch("[^\r\n]+") do
    local user = line:match("^([^:]+):")
    if user and not lib.contains(readme.admins, user) and not lib.contains(readme.users, user) then
      lib.log("pdbedit -x -u " .. lib.shell_quote(user), "Unauthorized Samba user: " .. user)
    end
  end
end

local function samba_wanted()
  return slib.service_in_readme("samba") or slib.service_in_readme("smbd")
end

return {
  check_samba = function()
    local installed = {}
    for _, unit in ipairs(SAMBA_UNITS) do
      if slib.service_installed(unit) then table.insert(installed, unit) end
    end
    if #installed == 0 then return end

    if not samba_wanted() then
      for _, unit in ipairs(installed) do slib.disable_service(unit) end
      return
    end

    local content = lib.read_file(SMB_CONF)
    if not content then
      lib.log(nil, "Can't read " .. SMB_CONF .. ", skipping samba checks")
      return
    end

    local sections, order = parse_conf(content)
    local changed = audit_global(sections)
    changed = audit_shares(sections, order) or changed
    audit_samba_users()

    if changed then
      -- validate first so a typo can't take a required service down
      lib.log("testparm -s >/dev/null 2>&1 && systemctl restart smbd", "Validate smb.conf, then restart Samba")
    end
  end
}
