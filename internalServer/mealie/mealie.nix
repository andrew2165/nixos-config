{ config, pkgs, ... }: {

    # TODO: implement some kind of backup strategy for Mealie
    # outside of the daily vm images
    # https://github.com/mealie-recipes/mealie/discussions/4223
    
    # Just using the karakeep user 
    age.secrets.tanker-mealie-smb-pswd = {
        file = ./../../secrets/tanker-karakeep-smb-pswd.age;
    };

    systemd.mounts = [{
        description = "mealie backup mount";
        what = "//100.113.228.33/self-hosted-services/mealie";
        where = "/mnt/mealie";
        type = "cifs";
        options = let
                credentials = config.age.secrets.tanker-mealie-smb-pswd.path;
            in "credentials=${credentials},rw,file_mode=0777,dir_mode=0777";
    }];
    systemd.automounts = [{
        description = "Automount for Mealie";
        where = "/mnt/mealie";
        wantedBy = [ "multi-user.target" ];
    }];


    age.secrets.mealie-env = {
        file = ./../../secrets/mealie-env.age;
        path = "/etc/mealie/mealie/.env";
    };
    age.secrets.mealie-postgres-env = {
        file = ./../../secrets/mealie-postgres-env.age;
        path = "/etc/mealie/postgres/.env";
    };


    # Must login through the tailscale IP using the user/pass in iCloud keychain
    # to get at the settings
    systemd.services.mealie-docker-compose = {
        path = [ 
            pkgs.docker-compose
            pkgs.docker
        ];
        script = ''
        docker-compose -f /home/andrew/nixos-config/internalServer/mealie/docker-compose.yml up --detach
        '';
        wantedBy = ["multi-user.target"];
        # If you use podman
        #after = ["podman.service" "podman.socket"];
        # If you use docker
        after = ["docker.service" "docker.socket"];
    };

}