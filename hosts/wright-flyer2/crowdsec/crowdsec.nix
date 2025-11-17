{ config, pkgs, ... }: {

    # TODO: write and deal with crowdsec config file

    systemd.services.crowdsec-podman-compose = {
        path = [ 
            pkgs.podman-compose
            pkgs.podman
        ];
        script = ''
        podman compose -f ${./crowdsec-compose.yml} up --detach
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
        after = ["podman.service" "podman.socket"];
        # If you use docker
        #after = ["docker.service" "docker.socket"];
    };

}