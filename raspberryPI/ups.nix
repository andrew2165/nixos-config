{ config, pkgs, lib, agenix, inputs, ... }: {

  # Enable NUT in netserver mode
  power.ups = {
    enable = true;
    mode = "netserver";

    # Define the connected UPS
    ups."eaton" = {
      driver = "usbhid-ups";  # Common driver for Eaton USB UPS
      port = "auto";
      description = "Eaton UPS";
      directives = [
        "override.battery.charge.low = 20"
        "override.battery.runtime.low = 300"
        "ignorelb"
      ];
    };
  };

  # Provide custom configuration files for NUT
  environment.etc = {
    # upsd.conf: Define listening interfaces
    "nut/upsd.conf".text = ''
      LISTEN 127.0.0.1 3493
      LISTEN 0.0.0.0 3493
    '';

    # upsd.users: Define users and permissions
    "nut/upsd.users".text = ''
      [${upsUser}]
        password = ${upsPassword}
        upsmon master
    '';

    # upsmon.conf: Define monitoring settings
    "nut/upsmon.conf".text = ''
      MONITOR ${upsName}@localhost 1 ${upsUser} ${upsPassword} master
      MINSUPPLIES 1
      SHUTDOWNCMD "${pkgs.systemd}/bin/systemctl poweroff"
      POLLFREQ 5
      POLLFREQALERT 5
      HOSTSYNC 15
      DEADTIME 15
      POWERDOWNFLAG /etc/killpower
      NOTIFYFLAG ONLINE SYSLOG
      NOTIFYFLAG ONBATT SYSLOG
      NOTIFYFLAG LOWBATT SYSLOG
      NOTIFYFLAG FSD SYSLOG
      RBWARNTIME 43200
      NOCOMMWARNTIME 300
      FINALDELAY 5
    '';
  };

  # Open NUT's default port for remote clients
  networking.firewall.allowedTCPPorts = [ 3493 ];

  # Ensure the nut user exists
  users.users.nut = {
    isSystemUser = true;
    group = "nut";
    home = "/var/lib/nut";
    createHome = true;
  };

  users.groups.nut = {};

  # Set appropriate permissions for USB devices
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="XXXX", ATTRS{idProduct}=="YYYY", MODE="664", GROUP="nut"
  '';


}