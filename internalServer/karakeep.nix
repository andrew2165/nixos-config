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

    age.secrets.tanker-karakeep-smb-pswd = {
        file = ../secrets/tanker-karakeep-smb-pswd.age;
    };
    age.secrets.karakeep-env-file = {
        file = ../secrets/karakeep-env-file.age;
        path = "/etc/karakeep/.env";
    };

    # Mount karakeep share
    # BUT karakeep does not do well with the SMB share being the location for the Volumes, if I had to bet the database throws a hissy fit
    # For mount.cifs, required unless domain name resolution is not needed.
    #environment.systemPackages = [ pkgs.cifs-utils ];
    networking.firewall.extraCommands = ''iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns'';
    fileSystems."/mnt/karakeep_share" = {
        device = "//100.113.228.33/karakeep";
        fsType = "cifs";
        options = let
            # this line prevents hanging on network split
            automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";
            # This "karakeep" pwd is for this server in general
            credentials = config.age.secrets.tanker-karakeep-smb-pswd.path;
        in ["${automount_opts},credentials=${credentials},uid=1000,gid=100"];
    };

    # rsync karakeep homedir to smb share for backup
    systemd.services.karakeep-rsync = {
        wantedBy = [ "multi-user.target" ];
        path = [
            pkgs.rsync
        ];
        script = ''
        while :
        do
            rsync -avu --delete "/home/andrew/karakeep/" "/mnt/karakeep_share"
            sleep 1800
            echo "synced - sleeping for 1800 seconds"
        done
        '';
    };

    # Start karakeep (& ollama) compose as systemd service
    systemd.services.karakeep-docker-compose = {
        path = [ 
            pkgs.docker-compose
            pkgs.docker
        ];
        script = ''
        docker-compose -f /home/andrew/nixos-config/internalServer/docker-compose.yml up --detach
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
        #after = ["podman.service" "podman.socket"];
        # If you use docker
        after = ["docker.service" "docker.socket"];
    };

}