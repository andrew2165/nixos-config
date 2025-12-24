{ config, pkgs, ... }: {

    # Quick note:
    # This service does actually fail, I am not 100% sure why at the moment
    # but I suspect it is because podman asks "hey which repo should I grab the base image from"
    # and that waits and waits and so systemd kills the process... Doesn't matter bc I manually
    # built the image that runs on the machine but good to know for the future.

    systemd.services.tekkit-podman-compose = {
        path = [ 
            pkgs.podman-compose
            pkgs.podman
            pkgs.git
        ];
        script = ''
        podman compose -f ${./docker-compose.yaml} up --detach
        '';
        wantedBy = ["multi-user.target"];
        # If you use podman
        after = ["podman.service" "podman.socket"];
        # If you use docker
        # after = ["docker.service" "docker.socket"];
    };

}