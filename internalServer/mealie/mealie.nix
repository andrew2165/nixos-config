{ config, pkgs, ... }: {

    age.secrets.mealie-env = {
        file = ./../../secrets/mealie-env.age;
        path = "/etc/mealie/mealie/.env";
    };
    age.secrets.mealie-postgres-env = {
        file = ./../../secrets/mealie-postgres-env.age;
        path = "/etc/mealie/postgres/.env";
    };

    # TODO: implement some kind of backup strategy for Mealie
    # outside of the daily vm images

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