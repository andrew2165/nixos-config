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