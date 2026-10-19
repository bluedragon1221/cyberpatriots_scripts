local lib = require("lib")
local slib = require("services.lib")

BAD_SERVICES = {
  "squid"
}
local function check_bad_services()
  for _, srv in ipairs(BAD_SERVICES) do
    if slib.service_installed(srv) then
      slib.disable_service(srv)
    end
  end
end

local M = {}

local nginx = require("services.nginx")
local apache = require("services.apache")
local vsftpd = require("services.vsftpd")
local sshd = require("services.sshd")
local samba = require("services.samba")

function M.check_services()
  check_bad_services()
  nginx.check_nginx()
  apache.check_apache()
  vsftpd.check_vsftpd()
  sshd.check_sshd()
  samba.check_samba()
end

return M
