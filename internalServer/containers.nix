{ config, pkgs, ... }: {

    # Nix file for all of the containerized services running
    # Running:
    # Karakeep
    # Ollama

    # Enable common container config files in /etc/containers
    virtualisation.containers.enable = true;
    virtualisation.docker.enable = true;
    #virtualisation = {
    #podman = {
    #    enable = true;
    #    # Create a `docker` alias for podman, to use it as a drop-in replacement
     #   dockerCompat = true;
     #   # Required for containers under podman-compose to be able to talk to each other.
    #    defaultNetwork.settings.dns_enabled = true;
    #    };
    #};

    age.secrets.tanker-karakeep-smb-pswd.file = ../secrets/tanker-karakeep-smb-pswd.age;

    # Mount karakeep share
    # For mount.cifs, required unless domain name resolution is not needed.
    #environment.systemPackages = [ pkgs.cifs-utils ];
    networking.firewall.extraCommands = ''iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns'';
    fileSystems."/mnt/karakeep_share" = {
        device = "//100.113.228.33/karakeep";
        fsType = "cifs";
        options = let
            # this line prevents hanging on network split
            automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";
            credentials = config.age.secrets.tanker-karakeep-smb-pswd.path;
        in ["${automount_opts},credentials=${credentials},uid=1000,gid=100"];
    };

    # TODO: this only stores things locally as the database doesnt play nice
    # with the smb share so figure out how to sync things
    # Decrypt .env file with secrets
    # age.secrets.karakeep-env-file = {
    #     file = ../secrets/karakeep-env-file.age;
    #     path = "/home/andrew/nixos-config/internalServer/";
    # };

    # Start karakeep compose as systemd service
    systemd.services.karakeep-docker-compose = {
        path = [ 
            pkgs.docker-compose
            pkgs.docker
        ];
        script = ''
        docker-compose -f /home/andrew/nixos-config/internalServer/docker-compose.yml up --detach
        '';
        wantedBy = ["multi-user.target"];
        # If you use podman
        #after = ["podman.service" "podman.socket"];
        # If you use docker
        after = ["docker.service" "docker.socket"];
    };

    # TODO: figure out where to host networked ollama

    # systemd.services.ollama = {
    #     path = [
    #         pkgs.docker
    #     ];
    #     script = ''
    #         docker run -d -v ~/ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama:0.6.8
    #     '';
    #     wantedBy = ["multi-user.target"];
    #     # If you use podman
    #     #after = ["podman.service" "podman.socket"];
    #     # If you use docker
    #     after = ["docker.service" "docker.socket"];
    # };

}