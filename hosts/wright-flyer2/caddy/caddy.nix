{ config, caddyPkgs, ... }: {

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
        package = caddyPkgs.caddy.withPlugins {
            plugins = [ 
                "github.com/greenpau/caddy-security@v1.6.2"
                "github.com/hslatman/caddy-crowdsec-bouncer/http@v0.15.0"
            ];
            # Update this hash when the Caddy or plugin sources change.
            hash = "sha256-g2XzFvc4vn8Ou6HWNOI2AufMaHx1DwJb3pKvX8sNIJI=";
            doInstallCheck = false;
        };
        logDir = "/var/log/caddy";
    };

 
}
