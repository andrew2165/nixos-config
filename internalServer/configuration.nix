{ config, pkgs, ... }:
 
 {
   nix.settings = {
     experimental-features = "nix-command flakes";
   };

   imports = [
    # Include hardware scan
    ./hardware-configuration.nix
    ./containers.nix
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
   ];
   
   /*
   fileSystems."/" = {
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
   boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "ext4" ];
   
   users.users = {
     root.hashedPassword = "!"; # Disable root login
     andrew = {
       name = "andrew";
       isNormalUser = true;
       extraGroups = [ 
        "wheel"
        "networkmanager" 
        "podman"
       ];
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

   services.caddy = {
      enable = true;

      virtualHosts."internaltest.stewartinternal.com".extraConfig = ''
        tls internal
        respond "Hello, internal!"
      '';

      virtualHosts."pdf.stewartinternal.com".extraConfig = ''
        tls internal
        reverse_proxy 100.83.80.45:8080
      '';

      virtualHosts."endeavor.stewartinternal.com".extraConfig = ''
        tls internal
        reverse_proxy 100.103.150.122:8006
      '';

      virtualHosts."tanker.stewartinternal.com".extraConfig = ''
        tls internal
        reverse_proxy 100.113.228.33
      '';
   };
   
   networking.hostName = "internalServer"; # Define your hostname.
   networking.firewall = {
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ 41641 ];
   };
   
   system.stateVersion = "24.11";
 }