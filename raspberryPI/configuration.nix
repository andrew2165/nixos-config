{ config, pkgs, lib, ... }:
{
    # TODO: finish tailscale config by establishing secrets management
    services.tailscale = {
        enable = true;
        useRoutingFeatures = "both";
        extraUpFlags = [ "--advertise-exit-node" ];
    };

}