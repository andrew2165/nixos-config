{
  description = "NixOS VM configuration & more";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    # home-manager, used for managing user configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, home-manager, ... } @ input: {
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

        nixosISO = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./liveISO/configuration.nix
          ];
        };
      };
    };
}
