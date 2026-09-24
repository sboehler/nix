{
  config,
  pkgs,
  lib,
  ...
}:
{
  determinateNix = {
    # Enable Determinate to handle your Nix configuration
    enable = true;

    # Custom Determinate Nix settings written to /etc/nix/nix.custom.conf
    customSettings = {
      # Enables parallel evaluation (remove this setting or set the value to 1 to disable)
      eval-cores = 0;
      extra-experimental-features = [
        "build-time-fetch-tree" # Enables build-time flake inputs
      ];
      # Other settings
    };
  };
}
