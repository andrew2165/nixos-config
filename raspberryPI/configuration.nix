{ config, pkgs, lib, ... }:
{
    # TODO: get hardware scan
    imports = [
        # Include the results of the hardware scan.
        #./hardware-configuration.nix
    ];

    # TODO: finish tailscale config by establishing secrets management
    services.tailscale = {
        enable = true;
        useRoutingFeatures = "both";
        extraUpFlags = [ "--advertise-exit-node" ];
    };

}