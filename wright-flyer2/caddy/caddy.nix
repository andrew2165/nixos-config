{ config, pkgs, ... }: {

    # TODO: configure firewall port forwarding to allow for rootless container binding to lower ports
    # https://wiki.nixos.org/wiki/Docker

    # TODO: configure systemd service to build and start the container
    systemd.services.caddy-container = {
        path = [
            pkgs.podman
        ];
        script = ''
        podman compose -f /home/andrew/nixos-config/wright-flyer2/caddy/compose.yaml up --detach
        '';
        wantedBy = ["multi-user.target"];
        # If you use podman
        after = ["podman.service" "podman.socket"];
        # If you use docker
        # after = ["docker.service" "docker.socket"];
    };

    # TODO: deploy caddy file using agenix

}