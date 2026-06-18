{ config, pkgs, ... }: {

    age.secrets.pocket-id-env = {
        file = ./../../../secrets/pocket-id-env.age;
        path = "/etc/pocket-id/.env";
    };

    systemd.services.pocket-id-docker-compose = {
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
