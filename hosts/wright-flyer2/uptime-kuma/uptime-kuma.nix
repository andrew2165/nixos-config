{ config, pkgs, ... }: {

    services.uptime-kuma = {
        enable = true;
        settings = {
            PORT = "4000";
            DATA_DIR = "/var/lib/uptime-kuma/"
        };
    };

}