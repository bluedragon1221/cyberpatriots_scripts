lib = require("lib")

users = require("users")
packages = require("packages")
services = require("services")
cron = require("cron")
misc = require("misc")

lib.clear_log() -- fresh run
users.check_users()
misc.check_harmful_files()
packages.check_packages()
cron.check_cron()
services.check_nginx()
services.check_misc_services()
misc.check_firewall()
misc.check_syn_cookies()
packages.check_autoupgrade()
packages.update_packages()
