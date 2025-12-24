{ config, pkgs, ... }: {

    systemd.services.tekkit-podman-compose = {
        path = [ 
            pkgs.podman-compose
            pkgs.podman
            git
        ];
        script = ''
        podman compose -f ${./docker-compose.yaml} up --build --detach
        '';
        wantedBy = ["multi-user.target"];
        # If you use podman
        after = ["podman.service" "podman.socket"];
        # If you use docker
        # after = ["docker.service" "docker.socket"];
    };

}