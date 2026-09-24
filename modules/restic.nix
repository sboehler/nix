{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment = {
    systemPackages = with pkgs; [
      restic
    ];
  };

  sops = {
    secrets = {
      b2_account_id = {
        owner = config.users.users.silvio.name;
      };
      b2_account_key = {
        owner = config.users.users.silvio.name;
      };
      restic_password = {
        owner = config.users.users.silvio.name;
      };
      ssh_config = {
        format = "binary";
        sopsFile = ../secrets/ssh_config.text;
        owner = "root";
        mode = "0555";
      };
      rsyncnet_identity = {
        owner = config.users.users.silvio.name;
        mode = "0400";
      };
      restic_repository_pictures = {
        owner = config.users.users.silvio.name;
      };
      restic_repository_music = {
        owner = config.users.users.silvio.name;
      };
      restic_repository_repos = {
        owner = config.users.users.silvio.name;
      };
      restic_repository_software = {
        owner = config.users.users.silvio.name;
      };
    };
    templates = {
      b2_environment_file = {
        content = ''
          B2_ACCOUNT_ID="${config.sops.placeholder.b2_account_id}"
          B2_ACCOUNT_KEY="${config.sops.placeholder.b2_account_key}"
        '';
        owner = config.users.users.silvio.name;
      };
    };
  };

  programs.ssh.extraConfig = ''
    Include /run/secrets/ssh_config
  '';

  services = {
    restic = {
      backups =
        let
          tmpl = {
            environmentFile = "/run/secrets/rendered/b2_environment_file";
            passwordFile = "/run/secrets/restic_password";
            pruneOpts = [
              "--keep-hourly 24"
              "--keep-daily 31"
              "--keep-monthly 1200"
              "--group-by ''"
            ];
            user = "silvio";
            timerConfig = {
              OnCalendar = "*-*-* 03:00:00";
              RandomizedDelaySec = "1h";
            };
          };
        in
        {
          pictures-b2 = tmpl // {
            repositoryFile = config.sops.secrets.restic_repository_pictures.path;
            paths = [ "/data/pictures" ];
          };
          repos-b2 = tmpl // {
            repositoryFile = config.sops.secrets.restic_repository_repos.path;
            paths = [ "/data/repos" ];
          };
          music-b2 = tmpl // {
            repositoryFile = config.sops.secrets.restic_repository_music.path;
            paths = [
              "/data/music/Lossless"
              "/data/music/Lossy"
            ];
          };
          software-b2 = tmpl // {
            repositoryFile = config.sops.secrets.restic_repository_software.path;
            paths = [ "/data/software" ];
          };

          pictures-rsyncnet = tmpl // {
            repository = "sftp:rsyncnet:restic/pictures";
            paths = [ "/data/pictures" ];
          };
          repos-rsyncnet = tmpl // {
            repository = "sftp:rsyncnet:restic/repos";
            paths = [ "/data/repos" ];
          };
          music-rsyncnet = tmpl // {
            repository = "sftp:rsyncnet:restic/music";
            paths = [
              "/data/music/Lossless"
              "/data/music/Lossy"
            ];
          };
          email-rsyncnet = tmpl // {
            repository = "sftp:rsyncnet:restic/emails";
            paths = [
              "/data/backup/emails"
            ];
          };
        };
    };
  };
}
