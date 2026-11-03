{
  description = "A flake template for nix-darwin and Determinate Nix";

  # Flake inputs
  inputs = {

    # Stable Nixpkgs (use 0.1 for unstable)
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";

    # Unstable Nixpkgs, for packages that need to track upstream closely
    nixpkgs-unstable.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

    # Stable nix-darwin (use 0.1 for unstable)
    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Determinate 3.* module
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SOPS secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Flake outputs
  outputs =
    { self, ... }@inputs:
    let
      # Shared nixpkgs config for instances we import ourselves
      config = {
        allowUnfree = true;
      };

      # Unstable nixpkgs instance, for packages that track upstream closely
      pkgs-unstable =
        system:
        import inputs.nixpkgs-unstable {
          inherit system config;
        };

      mkSpecialArgs = system: {
        inherit inputs;
        pkgs-unstable = pkgs-unstable system;
      };
    in
    {
      # nix-darwin configuration output
      darwinConfigurations.mba = inputs.nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = mkSpecialArgs "aarch64-darwin";
        modules = [
          ./hosts/macbook
        ];
      };

      # nix-darwin configuration output
      darwinConfigurations.mbp = inputs.nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = mkSpecialArgs "aarch64-darwin";
        modules = [
          ./hosts/macbook
        ];
      };

      nixosConfigurations.thinkpad = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = mkSpecialArgs "x86_64-linux";
        modules = [
          ./hosts/thinkpad
        ];
      };

      nixosConfigurations.shuttle = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = mkSpecialArgs "x86_64-linux";
        modules = [
          ./hosts/shuttle
        ];
      };
    };
}
