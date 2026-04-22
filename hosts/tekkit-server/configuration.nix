{ pkgs, ... }: {

    imports = [
        #./tekkit-server/tekkit.nix
        #./tekkit-server/docker-compose.nix
        ./java-bedrock-server/docker-compose.nix
    ];

    nix.settings = {
        experimental-features = "nix-command flakes";
    };
   
    environment.systemPackages = with pkgs; [
        vim
        tmux
        git
        htop
        fastfetch
        podman
        podman-tui
        podman-compose # start group of containers for dev
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
   
    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";
    console.keyMap = "us";

    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/sda";
    boot.loader.grub.configurationLimit = 5; # Number of configs retained
    boot.initrd.availableKernelModules = [ 
        "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "ext4" 
    ];

    # Enable automatic garbage collection
    nix.gc.automatic = true;

    users.users = {
        root.hashedPassword = "!"; # Disable root login
        andrew = {
            name = "andrew";
            isNormalUser = true;
            extraGroups = [ 
                "wheel" 
                "podman"
            ];
            openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZCeaMfoy/5Tef0FnIkLrqhE6BIvjL+XfIDXczkTiDR andrew"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFTSJ+CahcqGec/tsOcZDxsAyFQ1h8TxCgVxq1bSePr jonathanstewart"
            ];
        };
    };
   
    security.sudo.wheelNeedsPassword = true;

    # Lock down Nix to only wheel
    nix.settings.allowed-users = [ "@wheel" ];
   
    services.openssh = {
        enable = true;
        allowSFTP = false;
        challengeResponseAuthentication = false;
        settings = {
            PermitRootLogin = "no";
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
        };
    };

    services.fail2ban = {
        enable = true;
        bantime = "168h";
    };
   
   networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 
            22
            25565
            # 80
            # 8000
            # 53
            # 5300
            # 443
            # 8443
        ];
        allowedUDPPorts = [
            25565
            # 53
            # 5300
            # 443
            # 8443
        ];
   };

    # This section go moved to ./tekkit-server/docker-compose.nix
    # # Enable common container config files in /etc/containers
    # virtualisation.containers.enable = true;
    # virtualisation = {
    #     podman = {
    #         enable = true;

    #         # Create a `docker` alias for podman, to use it as a drop-in replacement
    #         dockerCompat = true;

    #         # Required for containers under podman-compose to be able to talk to each other.
    #         defaultNetwork.settings.dns_enabled = true;
    #     };
    # };

    networking.hostName = "tekkit-server";
    system.stateVersion = "25.11";
 }
