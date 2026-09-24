{ pkgs, config, ... }:
{
  sops = {
    secrets = {
      "tailscale_auth_key" = { };
    };
  };

  services = {
    tailscale = {
      enable = true;
      authKeyFile = "/run/secrets/tailscale_auth_key";
    };
  };

}
