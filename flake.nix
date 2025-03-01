{
  description = "NixOS VM configuration & more";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    # home-manager, used for managing user configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nixos-generators for building live images, sd card, etc.
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, home-manager, nixos-generators, ... } @ input: {

        # Formats used by Nixos-generators as a module
        # A single nixos config outputting multiple formats.
        # Alternatively put this in a configuration.nix.
        nixosModules.myFormats = { config, ... }: {
          imports = [
            nixos-generators.nixosModules.all-formats
          ];

          nixpkgs.hostPlatform = "x86_64-linux";

          formatConfigs.nixosISO = { config, modulesPath, ... }: {
            imports = [ 
              "${toString modulesPath}/installer/cd-dvd/installation-cd-base.nix"
              ./liveISO/configuration.nix
            ];
            formatAttr = "isoImage";
            fileExtension = ".iso";
          };

          # customize an existing format
          # formatConfigs.vmware = { config, ... }: {
          #   services.openssh.enable = true;
          #   modules = [
          #     ./liveISO/configuration.nix
          #   ];
          # };

          # define a new format
          #formatConfigs.my-custom-format = { config, modulesPath, ... }: {
          #  imports = [ "${toString modulesPath}/installer/cd-dvd/installation-cd-base.nix" ];
          # formatAttr = "isoImage";
          #  fileExtension = ".iso";
          #  networking.wireless.networks = {
              # ...
          #  };
          #};
        };
      
      # Defining my Nixos Configurations
      nixosConfigurations = {
        
        nixosVM = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./nixosVM/configuration.nix

            # make home-manager as a module of nixos
            # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
            home-manager.nixosModules.home-manager {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.users.andrew = import ./nixosVM/home.nix;

              # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
            }
          ];
        };

        # TODO: Check to see if the network settings in the config work
        # https://github.com/nix-community/nixos-generators
        # run ex: nix build .#nixosConfigurations.my-machine.config.formats.vmware
        # for this one: nix build .#nixosConfigurations.nixosISO.config.formats.nixosISO
        nixosISO = nixpkgs.lib.nixosSystem {
          modules = [
            self.nixosModules.myFormats
            #./liveISO/configuration.nix
          ];
        };
      };
    };
}
