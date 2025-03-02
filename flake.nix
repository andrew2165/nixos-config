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
        
        # https://github.com/nix-community/nixos-generators
        # run ex: nix build .#nixosConfigurations.my-machine.config.formats.vmware
        # for this one: nix build .#nixosConfigurations.nixosISO.config.formats.nixosISO
      };

      packages.x86_64-linux = {
        liveISO = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          modules = [
            ./liveISO/configuration.nix
          ];
          format = "iso";
        };
      };
    };
}
