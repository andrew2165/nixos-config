{ config, pkgs, lib, ... }:
{
    # Things here are included in the rebuild of a remote deploy but not the initial SD img

    # TODO: get hardware scan
    # actually, do I even need to HW scan??
    imports = [
        # Include the results of the hardware scan.
        ./hardware-configuration.nix
    ];

    services.tailscale = {
        enable = true;
        authKeyFile = age.secrets."tailscale-auth-key1.age".path;
    };

}