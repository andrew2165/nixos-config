{ config, pkgs, ... }: {

    # Nix file for all of the containerized services running
    # Running:
    # Karakeep
    # Ollama

    # Enable common container config files in /etc/containers
    virtualisation.containers.enable = true;
    virtualisation = {
    podman = {
        enable = true;
        # Create a `docker` alias for podman, to use it as a drop-in replacement
        dockerCompat = true;
        # Required for containers under podman-compose to be able to talk to each other.
        defaultNetwork.settings.dns_enabled = true;
        };
    };

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

    # TODO: stand up karakeep with docker compose
    # Decrypt .env file with secrets
    age.secrets.karakeep-env-file = {
        file = ../secrets/karakeep-env-file.age;
        path = "./.env";
    };

    # Start karakeep compose as systemd service
    systemd.services.karakeep-docker-compose = {
        script = ''
        podman compose -f ${./docker-compose.yml}
        '';
        wantedBy = ["multi-user.target"];
        # If you use podman
        after = ["podman.service" "podman.socket"];
        # If you use docker
        # after = ["docker.service" "docker.socket"];
    };

    # TODO: figure out where to host networked ollama

}