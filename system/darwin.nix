{ inputs, ... }:
{
  imports = [
    inputs.determinate.darwinModules.default
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.silvio = {
    imports = [
      ../home/common.nix
      ../home/darwin.nix
    ];
  };

  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    secrets = {
      shuttle_mac_address = {
        owner = "silvio";
      };
    };
  };
}
