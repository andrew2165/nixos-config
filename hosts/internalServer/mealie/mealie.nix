{ config, pkgs, ... }: {

    # TODO: implement some kind of backup strategy for Mealie
    # outside of the daily vm images
    # https://github.com/mealie-recipes/mealie/discussions/4223
    
    # Just using the karakeep user 
    age.secrets.tanker-mealie-smb-pswd = {
        file = ./../../../secrets/tanker-karakeep-smb-pswd.age;
    };

    systemd.mounts = [{
        description = "mealie backup mount";
        what = "//100.113.228.33/self-hosted-services";
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

    age.secrets.mealie-backup-py = {
        file = ./../../../secrets/mealie-backup-py.age;
    };

    # Trigger a backup through api with python
    # https://github.com/mealie-recipes/mealie/discussions/4223
    # https://discourse.nixos.org/t/start-python-script-from-systemd-unit/4520 
    systemd.timers."mealie-backup" = {
        wantedBy = [ "timers.target" ];
            timerConfig = {
                #OnBootSec = "5m";
                #OnUnitActiveSec = "5m";
                OnCalendar = "daily";
                Persistent = true;
                Unit = "mealie-trigger-backup.service";
            };
    };
    systemd.services."mealie-trigger-backup" = let
            myPythonEnv = pkgs.python313.withPackages (ps: with ps; [ requests ]);
            python_backup_script = config.age.secrets.mealie-backup-py.path;
        in {
            path = [ myPythonEnv ];
            script = ''
                set -eu
                ${myPythonEnv}/bin/python ${python_backup_script}
            '';
            serviceConfig = {
                Type = "oneshot";
                User = "root";
            };
        };


    # rsync mealie homedir to smb share for backup
    systemd.services.mealie-rsync = {
        wantedBy = [ "multi-user.target" ];
        path = [
            pkgs.rsync
        ];
        script = ''
        while :
        do
            rsync -avu --delete "/home/andrew/mealie" "/mnt/mealie/mealie"
            sleep 21600
            echo "synced - sleeping for 21600 seconds (6h)"
        done
        '';
    };


    age.secrets.mealie-env = {
        file = ./../../../secrets/mealie-env.age;
        path = "/etc/mealie/mealie/.env";
    };
    age.secrets.mealie-postgres-env = {
        file = ./../../../secrets/mealie-postgres-env.age;
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
        docker compose -f ${./docker-compose.yml} up --detach
        '';
        wantedBy = ["multi-user.target"];
        # If you use podman
        #after = ["podman.service" "podman.socket"];
        # If you use docker
        after = ["docker.service" "docker.socket"];
    };

}