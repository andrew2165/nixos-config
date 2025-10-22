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
    
    age.secrets.tanker-paperless-smb-pswd.file = ./../../../secrets/tanker-karakeep-smb-pswd.age;
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

    age.secrets.paperless = {
        file = ./../../../secrets/paperless.age;
        mode = "777";
        path = "/home/andrew/nixos-config/internalServer/paperless/docker-compose.env";
    };
    
    systemd.services.paperless-docker-compose = {
        path = [ 
            pkgs.docker-compose
            pkgs.docker
        ];
        script = ''
        docker-compose -f /home/andrew/nixos-config/internalServer/paperless/docker-compose.yml up --detach
        '';
        ## For some reason this will frequently reload the systemd service
        ## not sure why so commented out 
        # reload = ''
        # docker-compose -f /home/andrew/nixos-config/internalServer/docker-compose.yml down &&
        # docker-compose -f /home/andrew/nixos-config/internalServer/docker-compose.yml up --detach
        # '';
        # preStop = ''
        # docker-compose -f /home/andrew/nixos-config/internalServer/docker-compose.yml down
        # '';
        wantedBy = ["multi-user.target"];
        # If you use podman
        #after = ["podman.service" "podman.socket"];
        # If you use docker
        after = ["docker.service" "docker.socket"];
    };

}