{ inputs, ... }:
{
  imports = [
    inputs.determinate.darwinModules.default
    inputs.home-manager.darwinModules.home-manager
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.silvio = {
    imports = [
      ../home/common.nix
      ../home/darwin.nix
    ];
  };
}
