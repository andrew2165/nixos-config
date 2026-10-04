{ config, pkgs, ... }: {

    age.secrets.wright-flyer-caddyfile = {
        file = ./../../../secrets/wright-flyer-caddyfile.age;
        owner = "caddy";
    };


    # Keep install checks disabled for plugin subdirectory false positives.
    # See https://github.com/NixOS/nixpkgs/issues/430090
    services.caddy = {
        #user = "caddy";
        enable = true;
        configFile = config.age.secrets.wright-flyer-caddyfile.path;
        package = pkgs.caddy.withPlugins {
            plugins = [ 
                "github.com/greenpau/caddy-security@v1.1.31"
                "github.com/hslatman/caddy-crowdsec-bouncer/http@v0.14.1"
            ];
            # Replace with the reported hash after changing plugin versions.
            hash = "sha256-fxxKIJEires69ED4N02HRROZ39A7b+MRw55VlC+Etdc=";
            doInstallCheck = false;
        };
        logDir = "/var/log/caddy";
    };

 
}
