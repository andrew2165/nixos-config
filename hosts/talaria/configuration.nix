{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./hermes/hermes.nix
  ];

  services.qemuGuest.enable = true;

  age.identityPaths = [ "/home/andrew/.ssh/id_ed25519" ];

  nix.settings = {
    experimental-features = "nix-command flakes";
    allowed-users = [ "@wheel" ];
  };

  environment.systemPackages = with pkgs; [
    vim
    tmux
    git
    htop
    fastfetch
  ];

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Enable automatic garbage collection
  nix.gc.automatic = true;

  users.users = {
    root.hashedPassword = "!"; # Disable root password login
    andrew = {
      name = "andrew";
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZCeaMfoy/5Tef0FnIkLrqhE6BIvjL+XfIDXczkTiDR andrew"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFTSJ+CahcqGec/tsOcZDxsAyFQ1h8TxCgVxq1bSePr jonathanstewart"
      ];
    };
  };

  # Set andrew's password locally with passwd for sudo access.
  security.sudo.wheelNeedsPassword = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  services.tailscale.enable = true;

  networking.hostName = "talaria";
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    interfaces.tailscale0.allowedTCPPorts = [ 9119 ];
  };

  system.stateVersion = "26.05";
}
