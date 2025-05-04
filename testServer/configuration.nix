{ config, pkgs, ... }:
 
 {
   nix.settings = {
     experimental-features = "nix-command flakes";
   };
   
   environment.systemPackages = with pkgs; [
     vim
     git
     fastfetch
     fail2banhtop
     tmux
     manix # for looking up nix documentation
     nixfmt-rfc-style
   ];
   
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
   
   networking.firewall.allowedTCPPorts = [ 22 ];
   
   system.stateVersion = "24.11";
 }