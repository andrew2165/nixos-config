{ pkgs, ... }: {

    # Temporary fix to mitigate copy/fail vuln
    # https://discourse.nixos.org/t/is-nixos-affected-by-copy-fail-edit-yes-it-is/77317/5
    boot.kernelPackages = pkgs.linuxPackages_6_18;

    imports = [
        ./caddy/caddy.nix
        ./uptime-kuma/docker-compose.nix
        #./crowdsec/crowdsec.nix
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
    boot.loader.grub.configurationLimit = 3; # Number of configs retained
    boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "ext4" ];

    # Enable automatic garbage collection
    nix.gc.automatic = true;

    users.users = {
        root.hashedPassword = "!"; # Disable root login
        andrew = {
            name = "andrew";
            isNormalUser = true;
            extraGroups = [ 
                "wheel" 
                "docker"
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
        settings = {
            PermitRootLogin = "no";
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
        };
    };

   services.tailscale = {
        enable = true;
        extraSetFlags = [
            "--accept-dns=false"
            "--advertise-exit-node"
        ];
   };
   
   networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 
            80
            8000
            # 53
            # 5300
            443
            8443
        ];
        allowedUDPPorts = [
            # 53
            # 5300
            443
            8443
            # config.services.tailscale.port
        ];
        # Always allow traffic from Tailscale network
        trustedInterfaces = [ "tailscale0" ];

        # Possible issues with running as exit node
        # see https://wiki.nixos.org/wiki/Tailscale
        # checkReversePath = "loose";
   };


    # Enable common container config files in /etc/containers
    virtualisation.containers.enable = true;
    virtualisation = {
        podman = {
            enable = true;

            # Create a `docker` alias for podman, to use it as a drop-in replacement
            dockerCompat = true;  
            
            autoPrune.enable = true;

            # Required for containers under podman-compose to be able to talk to each other.
            defaultNetwork.settings.dns_enabled = true;
        };
    };

    networking.hostName = "wright-flyer2";
    system.stateVersion = "25.05";
 }