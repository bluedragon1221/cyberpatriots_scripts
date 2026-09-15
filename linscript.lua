lib = require("lib")

users = require("users")
password_policy = require("password_policy")
packages = require("packages")
services = require("services")
sshd = require("sshd")
cron = require("cron")
misc = require("misc")

lib.clear_log() -- fresh run

-- escalate privileges
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
misc.check_firewall()
misc.check_sysctl()
misc.check_guest_login()

-- Packages stuff
packages.check_linuxmint_mirror()
packages.check_packages()
packages.update_packages()
