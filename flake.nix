{
  description = "NixOS configurations & more";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    # home-manager, used for managing user configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
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

  outputs = { self, nixpkgs, home-manager, nixos-generators, nixos-hardware, agenix, ... }@input: {
    # Defining my Nixos Configurations
    nixosConfigurations = {
      nixosVM = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./nixosVM/configuration.nix
          agenix.nixosModules.default 
          {
            environment.systemPackages = [ agenix.packages."x86_64-linux".default ];
            age.identityPaths = [ "/home/andrew/.ssh/id_ed25519" ];
            age.secrets."wifi-pswd".file = ./secrets/wifi-pswd.age;
            age.secrets."nixpi-andrew-pswd".file = ./secrets/nixpi-andrew-pswd.age;
          }

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

    # Nixos-Generators
    # run: sudo nix build .#liveISO
    packages.x86_64-linux = {
      liveISO = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = [ 
          ./liveISO/configuration.nix 
          agenix.nixosModules.default
          {
            environment.systemPackages = [ agenix.packages."x86_64-linux".default ];
            age.identityPaths = [ "/home/andrew/.ssh/id_ed25519" ];
            age.secrets."wifi-pswd".file = ../secrets/wifi-pswd.age;
            age.secrets."nixpi-andrew-pswd".file = ../secrets/nixpi-andrew-pswd.age;
          }
        ];
        format = "iso";
      };
    };
    # sudo nix build .#raspberryPi --system aarch64-linux
    # But must have cross compilation enabled, see nixos-generators documentation
    packages.aarch64-linux = {
      raspberryPi = nixos-generators.nixosGenerate {
        system = "aarch64-linux";
        modules = [
          ./raspberryPI/configuration.nix
          nixos-hardware.nixosModules.raspberry-pi-3
          agenix.nixosModules.default
          {
            environment.systemPackages = [ agenix.packages."aarch64-linux".default ];
            age.identityPaths = [ "/home/andrew/.ssh/id_ed25519" ];
            age.secrets."wifi-pswd".file = ../secrets/wifi-pswd.age;
            age.secrets."nixpi-andrew-pswd".file = ../secrets/nixpi-andrew-pswd.age;
            age.secrets."nixpi-andrew-pswd".path = "/nix/store/secrets/nixpi-andrew-pswd.age"
          }
        ];
        format = "sd-aarch64";
      };
    };
  };
}
