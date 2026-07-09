{ config, pkgs, ... }: {

    age.secrets.planka-env = {
        file = ./../../../secrets/planka-env.age;
        owner = "root";
        group = "root";
        mode = "400";
        path = "/etc/planka/.env";
    };

    systemd.services.planka-docker-compose = {
        path = [
            pkgs.coreutils
            pkgs.docker-compose
            pkgs.docker
        ];
        serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
        };
        preStart = ''
        install -d -m 0755 -o 1000 -g 100 /home/andrew/planka/data /home/andrew/planka/db-data
        '';
        script = ''
        set -eu
        docker compose --project-name planka -f ${./docker-compose.yml} up --detach
        '';
        preStop = ''
        set -eu
        docker compose --project-name planka -f ${./docker-compose.yml} down
        '';
        wantedBy = ["multi-user.target"];
        wants = ["docker.service" "tailscaled.service"];
        after = ["docker.service" "docker.socket" "tailscaled.service"];
    };

}
