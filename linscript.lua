lib = require("lib")

users = require("users")
password_policy = require("password_policy")
packages = require("packages")
services = require("services")
sshd = require("sshd")
selinux = require("selinux")
net = require("net")
files = require("files")
cron = require("cron")
misc = require("misc")

lib.clear_log()

require("escalate.lua").escalate_privileges()

-- Accounts stuff
users.check_users()
misc.check_harmful_files()
password_policy.check_login_defs()
password_policy.check_common_password()

-- Services stuff
cron.check_cron()
services.check_services()
sshd.check_sshd()
selinux.check_security_frameworks()
net.check_network_and_dns()
files.check_special_files()
misc.check_firewall()
misc.check_sysctl()
misc.check_guest_login()

packages.check_packages()
