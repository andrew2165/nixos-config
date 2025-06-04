{ config, pkgs, ... }: {

    networking.firewall.extraCommands = ''iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns'';
    # fileSystems."/mnt/paperless" = {
    #     device = "//100.113.228.33/paperless";
    #     fsType = "cifs";
    #     options = let
    #         # this line prevents hanging on network split
    #         automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users,file_mode=0770,dir_mode=0770";
    #         # This "karakeep" pwd is for this server in general
    #         credentials = config.age.secrets.tanker-karakeep-smb-pswd.path;
    #     in ["${automount_opts},credentials=${credentials},uid=1000,gid=100"];
    # };

    # https://discourse.nixos.org/t/systemd-mounts-and-systemd-automounts-options-causing-an-error/13796/2
    
    age.secrets.tanker-paperless-smb-pswd.file = ../secrets/tanker-karakeep-smb-pswd.age;
    systemd.mounts = [{
        description = "Paperless mount";
        what = "//100.113.228.33/paperless";
        where = "/mnt/paperless";
        type = "cifs";
        options = let
                credentials = config.age.secrets.tanker-paperless-smb-pswd.path;
            in "credentials=${credentials},rw,file_mode=0777,dir_mode=0777";
    }];
    systemd.automounts = [{
        description = "Automount for Paperless NGX";
        where = "/mnt/paperless";
        wantedBy = [ "multi-user.target" ];
        before = [ "paperless-scheduler.service" ];
    }];

    age.secrets.paperless.file = {
        file = ../secrets/paperless.age;
        mode = "777";
        path = /home/andrew/paperless/env_file;
    };
    age.secrets.paperless-web-key = {
        file = ../secrets/paperless-web-key.age;
        mode = "777";
        path = /home/andrew/paperless/web-key;
    };

    # Currently broken and the paperless-web.service fails bc it is missing
    # the PAPERLESS_SECRET_KEY so make sure to set it using secrets 
    # it can be any random string of characters
    services.paperless = {
        enable = false;
        user = "andrew";
        consumptionDir = "/mnt/paperless/ingest";
        consumptionDirIsPublic = true;
        address = "100.122.79.75";
        port = 8092;
        mediaDir = "/mnt/paperless/media";
        dataDir = "/mnt/paperless/data";
        environmentFile = config.age.secrets.paperless.path;
        settings = {
            PAPERLESS_SECRET_KEY = builtins.readFile config.age.secrets.paperless-web-key.path;
        };
        exporter = {
            enable = true;
            directory = "/mnt/paperless/backup";
            # default backup time is 01:30:00
        };
        database.createLocally = true; # Configure a PostegreSWL database for Paperless
    };

}