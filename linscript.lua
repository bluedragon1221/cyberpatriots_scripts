lib = require("lib")

users = require("users")
password_policy = require("password_policy")
packages = require("packages")
services = require("services")
cron = require("cron")
misc = require("misc")

lib.clear_log() -- fresh run

-- Accounts stuff
users.check_users()
misc.check_harmful_files()
password_policy.check_login_defs()
password_policy.check_common_password()

-- Services stuff
cron.check_cron()
services.check_apache()
services.check_ftp()
services.check_nginx()
services.check_ssh()
services.check_misc_services()
misc.check_firewall()
misc.check_sysctl()
misc.check_guest_login()

-- Packages stuff
packages.check_linuxmint_mirror()
packages.check_packages()
packages.update_packages()
