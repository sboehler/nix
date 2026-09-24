{
  config,
  pkgs,
  ...
}:
let
  cfg = {
    browseable = "yes";
    "valid users" = "${config.users.users.silvio.name}";
    "read only" = "no";
    "guest ok" = "no";
    "force user" = "${config.users.users.silvio.name}";
    "force group" = "users";
  };
in
{
  services = {
    samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          workgroup = "WORKGROUP";
          "server string" = "fileserver";
          "netbios name" = "fileserver";
          "guest account" = "nobody";
          "map to guest" = "bad user";
          "follow symlinks" = "yes";
        };
        pictures = cfg // {
          path = "/data/pictures";
        };
        software = cfg // {
          path = "/data/software";
        };
        music = cfg // {
          path = "/data/music";
        };
      };
    };
  };
}
