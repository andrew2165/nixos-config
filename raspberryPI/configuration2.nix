{ config, pkgs, lib, ... }:
{
    # https://discourse.nixos.org/t/flake-to-create-a-simple-sd-image-for-rpi4-cross/35185/24

    # Define Secrets Locations
    #age.secrets."wifi-pswd".file = ../secrets/wifi-pswd.age;
    #age.secrets."nixpi-andrew-pswd".file = ../secrets/nixpi-andrew-pswd.age;

    # TODO: get hardware scan
    # actually, do I even need to HW scan??
    imports = [
        # Include the results of the hardware scan.
        ./hardware-configuration.nix
    ];

}