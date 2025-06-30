{ config, pkgs, ... }:

{

  # Run as a vm, ename QEMU guest agent
  services.qemuGuest.enable = true;

  nix.settings = { experimental-features = "nix-command flakes"; };

  imports = [
    # Include hardware scan
    ./hardware-configuration.nix
    ./karakeep/karakeep.nix # also has some of the general system docker config, needs to fix TODO
    ./pocket-id/pocket-id.nix
    ./caddy/caddy.nix
    ./paperless/paperless.nix
    ./mealie/mealie.nix
  ];

  environment.systemPackages = with pkgs; [
    vim
    git
    fastfetch
    fail2ban
    htop
    tmux
    manix # for looking up nix documentation
    nixfmt-rfc-style
    cifs-utils
    #podman-compose
    docker
    docker-compose
    rsync
  ];

  /* fileSystems."/" = {
       device = "/dev/disk/by-label/nixos";
       fsType = "ext4";
     };
     fileSystems."/boot" = {
       device = "/dev/disk/by-label/boot";
       fsType = "ext4";
     };
     swapDevices = [
       {
         device = "/dev/disk/by-label/swap";
       }
     ];
  */

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.initrd.availableKernelModules =
    [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "ext4" ];
  boot.loader.grub.configurationLimit = 5; # Number of configs retained

  nix.optimise.automatic = true;
  nix.optimise.dates = [ "03:45" ]; # Optional; allows customizing optimisation schedule

  users.users = {
    root.hashedPassword = "!"; # Disable root login
    andrew = {
      name = "andrew";
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "podman" "docker" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZCeaMfoy/5Tef0FnIkLrqhE6BIvjL+XfIDXczkTiDR andrew"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFTSJ+CahcqGec/tsOcZDxsAyFQ1h8TxCgVxq1bSePr jonathanstewart"
      ];
    };
  };

  security.sudo.wheelNeedsPassword = true;

  nixpkgs.config.allowUnfree = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  services.tailscale.enable = true;

  networking.hostName = "internalServer"; # Define your hostname.
  networking.firewall = {
    allowedTCPPorts = [ 22 80 443 3000 11434 8092 ];
    allowedUDPPorts = [ 41641 ];
  };

  system.stateVersion = "24.11";
}
