{ pkgs, config, ... }:
{
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # Allows referencing 'docker' CLI if needed
  };

  sops = {
    secrets = {
      "garmin_username" = {
        owner = config.users.users.silvio.name;
        mode = "0400";
      };
      "garmin_password" = {
        owner = config.users.users.silvio.name;
        mode = "0400";
      };
    };
  };

  systemd = {
    services = {
      withings-sync = {
        description = "sync Withings data to Garmin";
        path = [
          pkgs.podman
          pkgs.zfs
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart =
            "${pkgs.podman}/bin/podman run "
            + "--rm "
            + "-v /var/withings-sync:/config "
            + "-v /run/secrets/garmin_password:/run/secrets/garmin_password "
            + "-v /run/secrets/garmin_username:/run/secrets/garmin_username "
            + "--pull=always "
            + "--name withings "
            + "ghcr.io/jaroslawhartman/withings-sync:latest "
            + "--features BLOOD_PRESSURE "
            + "--config-folder /config ";
        };
      };
    };

    timers = {
      withings-sync = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 07,08,09,10:15:00";
          Unit = "withings-sync.service";
        };
      };
    };
  };

  environment.systemPackages = [
    # Package 6.02 is broken as of 2026-08-31, therefore we use the
    # Docker image.
    # pkgs.python314Packages.withings-sync
  ];
}
