{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../../system/darwin.nix
    ../../modules/determinate.nix
  ];
  # Required for nix-darwin to work
  system.stateVersion = 1;

  users.users.silvio = {
    name = "silvio";
    home = "/Users/silvio";
    # See the reference docs for more on user config:
    # https://nix-darwin.github.io/nix-darwin/manual/#opt-users.users
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [

  ];

  # Other configuration parameters
  # See here: https://nix-darwin.github.io/nix-darwin/manual
}
