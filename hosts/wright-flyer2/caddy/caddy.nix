{ config, pkgs, ... }: {

    age.secrets.wright-flyer-caddyfile = {
        file = ./../../../secrets/wright-flyer-caddyfile.age;
        owner = "caddy";
    };


    # Issue with caddy plugins in sub directories & the corresponding go structure
    # that needed the install check to be overwridden.
    # Might be resolved in next release / unstable
    # https://github.com/NixOS/nixpkgs/issues/430090
    services.caddy = {
        #user = "caddy";
        enable = true;
        configFile = config.age.secrets.wright-flyer-caddyfile.path;
        package = (pkgs.caddy.withPlugins {
            plugins = [ 
                "github.com/greenpau/caddy-security@v1.1.31"
                "github.com/hslatman/caddy-crowdsec-bouncer/http@v0.9.2"
            ];
            # hash = pkgs.lib.fakeSha256; # useful for finding the real one
            hash = "sha256-IxKAYt6XgpCKDBJsRMyzeCq/uX7n5juySXP0sIOT4PQ=";
        }).overrideAttrs (finalAttr: prevAttrs: {
            doInstallCheck = false;
        }); # override bc of the location of the go 
        logDir = "/var/log/caddy";
    };

 
}