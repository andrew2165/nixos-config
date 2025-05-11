{ config, pkgs, ... }: {

    # Nix file for all of the containerized services running

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
    fileSystems."/mnt/karakeep_share" = {
        device = "//100.113.228.33/user/karakeep";
        fsType = "cifs";
        options = let
            # this line prevents hanging on network split
            automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";
            credentials = config.age.secrets.tanker-karakeep-smb-pswd.path;
        in ["${automount_opts},credentials=${credentials},uid=1000,gid=100"];
    };

    # TODO: stand up karakeep with docker compose

    # TODO: figure out where to host networked ollama

}