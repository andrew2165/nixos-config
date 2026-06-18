{ config, pkgs, ... }: {

    # Mealie has three intentionally separate backup paths:
    # 1. Daily API-triggered application backup.
    # 2. Periodic rsync of /home/andrew/mealie.
    # 3. Daily DB-aware pg_dumpall export to /mnt/mealie/mealie-db-dumps.
    #
    # Restore path:
    # - Prefer the Mealie app backup for normal application-level restores.
    # - Use the DB dump only when a Postgres-level restore is needed.
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

    systemd.timers."mealie-db-backup" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            Unit = "mealie-db-backup.service";
        };
    };
    systemd.services."mealie-db-backup" = {
        path = [
            pkgs.coreutils
            pkgs.docker
            pkgs.docker-compose
            pkgs.gzip
        ];
        script = ''
            set -eu
            umask 077

            backup_dir="/mnt/mealie/mealie-db-dumps"
            stamp="$(date -u +%Y%m%dT%H%M%SZ)"
            install -d -m 700 "$backup_dir"

            docker compose -f ${./docker-compose.yml} exec -T postgres \
                sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" pg_dumpall -U "$POSTGRES_USER"' \
                | gzip -c > "$backup_dir/mealie-postgres-$stamp.sql.gz"
        '';
        serviceConfig = {
            Type = "oneshot";
            User = "root";
        };
        wants = [ "mnt-mealie.automount" "docker.service" ];
        after = [ "mnt-mealie.automount" "docker.service" "docker.socket" ];
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
        serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
        };
        script = ''
        docker compose -f ${./docker-compose.yml} up --detach
        '';
        preStop = ''
        docker compose -f ${./docker-compose.yml} down
        '';
        wantedBy = ["multi-user.target"];
        wants = ["docker.service"];
        # If you use podman
        #after = ["podman.service" "podman.socket"];
        # If you use docker
        after = ["docker.service" "docker.socket"];
    };

}
