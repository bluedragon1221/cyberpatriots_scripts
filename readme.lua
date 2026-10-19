return {
  admins = {},
  users = {},

  -- group name -> members it should have (created if missing)
  groups = {
    -- spider = { "nova", "rowan", "finn", "quinn" },
  },

  -- required services: true = keep + harden, false/absent = disable if installed
  services = {
    vsftpd = false,
    nginx = false,
    apache2 = false
  },

  -- packages the README says to keep even though they're on the "hacking tools" list
  software = {
    -- "wireshark", "ophcrack",
  },
}
