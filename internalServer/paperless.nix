{ config, pkgs, ... }: {

    networking.firewall.extraCommands = ''iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns'';
    fileSystems."/mnt/paperless" = {
        device = "//100.113.228.33/paperless";
        fsType = "cifs";
        options = let
            # this line prevents hanging on network split
            automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";
            # This "karakeep" pwd is for this server in general
            credentials = config.age.secrets.tanker-karakeep-smb-pswd.path;
        in ["${automount_opts},credentials=${credentials},uid=1000,gid=100"];
    };

    age.secrets.paperless.file = ../secrets/paperless.age;

    services.paperless = {
        enable = true;
        consumptionDir = "/mnt/paperless/ingest";
        consumptionDirIsPublic = true;
        address = "100.122.79.75";
        port = 8092;
        mediaDir = "/mnt/paperless/media";
        dataDir = "/mnt/paperless/data";
        environmentFile = config.age.secrets.paperless.path;
        exporter = {
            enable = true;
            directory = "/mnt/paperless/backup";
            # default backup time is 01:30:00
        };
        database.createLocally = true; # Configure a PostegreSWL database for Paperless
    };

}