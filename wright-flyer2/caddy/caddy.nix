{ config, pkgs, ... }: {

    services.caddy = {
        enable = true;
        package = pkgs.caddy.withPlugins {
            plugins = [ 
                "github.com/greenpau/caddy-security@1.1.31"
                "github.com/hslatman/caddy-crowdsec-bouncer/crowdsec"
            ];
            hash = pkgs.lib.fakeSha256; # useful for finding the real one
            # hash = "";
        };
    };

    # # Configure firewall port forwarding to allow for rootless container binding to lower ports
    # # https://wiki.nixos.org/wiki/Docker
    # boot.kernel.sysctl = {
    #     "net.ipv4.conf.eth0.forwarding" = 1;    # enable port forwarding
    # };
    
    # networking = {
    #     firewall.extraCommands = ''
    #         iptables -A PREROUTING -t nat -i eth0 -p TCP --dport 80 -j REDIRECT --to-port 8000
    #         iptables -A PREROUTING -t nat -i eth0 -p TCP --dport 53 -j REDIRECT --to-port 5300
    #         iptables -A PREROUTING -t nat -i eth0 -p UDP --dport 53 -j REDIRECT --to-port 5300
    #     '';
    # };

    # # Configure systemd service to build and start the container
    # systemd.services.caddy-container = {
    #     path = [
    #         pkgs.podman
    #     ];
    #     script = ''
    #     podman compose -f /home/andrew/nixos-config/wright-flyer2/caddy/compose.yaml up --detach
    #     '';
    #     wantedBy = ["multi-user.target"];
    #     # If you use podman
    #     after = ["podman.service" "podman.socket"];
    #     # If you use docker
    #     # after = ["docker.service" "docker.socket"];
    # };

    # # TODO: deploy caddy file using agenix

}