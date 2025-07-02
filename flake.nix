{
  description = "NixOS configurations & more";

  inputs = {

    nixpkgs-24-11.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    # home-manager, used for managing user configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Agenix for secrets Management. Can be run ad hoc with:
    # nix run github:ryantm/agenix -- --help
    # nix run github:ryantm/agenix -- -e wifi-pswd.age
    agenix.url = "github:ryantm/agenix";

    # Nixos-generators for building live images, sd card, etc.
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-24-11, home-manager, nixos-generators, nixos-hardware
    , agenix, ... }@input: {
      # Defining my Nixos Configurations
      nixosConfigurations = {
        nixosVM = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./nixosVM/configuration.nix
            agenix.nixosModules.default
            {
              environment.systemPackages =
                [ agenix.packages."x86_64-linux".default ];
              age.identityPaths = [ "/home/andrew/.ssh/id_ed25519" ];
              age.secrets."wifi-pswd".file = ./secrets/wifi-pswd.age;
              age.secrets."nixpi-andrew-pswd".file =
                ./secrets/nixpi-andrew-pswd.age;
              age.secrets."tailscale-auth-key1.age".file =
                ./secrets/tailscale-auth-key1.age;
            }

            # make home-manager as a module of nixos
            # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.users.andrew = import ./nixosVM/home.nix;

              # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
            }
          ];
        };

        internalServer = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./internalServer/configuration.nix
            agenix.nixosModules.default
            {
              environment.systemPackages =
                [ agenix.packages."x86_64-linux".default ];
              age.identityPaths = [ "/home/andrew/.ssh/id_ed25519" ];
            }
          ];
        };

        wright-flyer2 = nixpkgs.lib.nixosSystem{
          system = "x86_64-linux";
          modules = [
            ./wright-flyer2/configuration.nix
            agenix.nixosModules.default
            {
              environment.systemPackages =
                [ agenix.packages."x86_64-linux".default ];
              age.identityPaths = [ "/home/andrew/.ssh/id_ed25519" ];
            }
          ];
        };

      };

      # For Remote Deploy
      # colmena apply --impure
      colmena = {
        meta = {
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
            #overlays = [ ];
          };
          specialArgs = { inherit agenix nixos-hardware; };
        };

        # note: nixPi-ups config moved to private repo
        nixPi = {
          deployment = {
            targetHost = "192.168.0.137";
            targetUser = "root";
          };
          imports = [
            agenix.nixosModules.default
            ./raspberryPI/configuration.nix
            ./raspberryPI/configuration2.nix
            nixos-hardware.nixosModules.raspberry-pi-3
            {
              environment.systemPackages =
                [ agenix.packages."aarch64-linux".default ];
              #age.identityPaths = [ "/home/andrew/.ssh/id_ed25519" ];
              #age.secrets."nixpi-andrew-pswd".file = ./secrets/nixpi-andrew-pswd.age;
              #age.secrets."tailscale-auth-key1.age".file = ./secrets/tailscale-auth-key1.age;
            }
          ];
        };
      };

      # Nixos-Generators
      # run: sudo nix build .#liveISO
      packages.x86_64-linux = {
        liveISO = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          modules = [
            ./liveISO/configuration.nix
            agenix.nixosModules.default
            {
              environment.systemPackages =
                [ agenix.packages."x86_64-linux".default ];
              age.identityPaths = [ "/home/andrew/.ssh/id_ed25519" ];
              age.secrets."wifi-pswd".file = ../secrets/wifi-pswd.age;
              age.secrets."nixpi-andrew-pswd".file =
                ../secrets/nixpi-andrew-pswd.age;
            }
          ];
          format = "iso";
        };
      };
      # sudo nix build .#raspberryPiSD --system aarch64-linux
      # But must have cross compilation enabled, see nixos-generators documentation
      packages.aarch64-linux = {
        raspberryPiSD = nixos-generators.nixosGenerate {
          system = "aarch64-linux";
          modules = [
            ./raspberryPI/configuration.nix
            nixos-hardware.nixosModules.raspberry-pi-3
            # agenix.nixosModules.default
            # {
            #   environment.systemPackages = [ agenix.packages."aarch64-linux".default ];
            #   age.identityPaths = [ "/home/andrew/.ssh/id_ed25519" ];
            #   age.secrets."wifi-pswd".file = ../secrets/wifi-pswd.age;
            #   age.secrets."nixpi-andrew-pswd".file = ../secrets/nixpi-andrew-pswd.age;
            #   age.secrets."nixpi-andrew-pswd".path = "/nix/store/secrets/nixpi-andrew-pswd.age";
            # }
          ];
          format = "sd-aarch64";
        };
      };
    };
}
