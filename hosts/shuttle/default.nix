{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    ./hardware-configuration.nix
    ../../system/nixos.nix
    ../../modules/mbsync.nix
    ../../modules/user.nix
    ../../modules/fileserver.nix
    ../../modules/withings-sync.nix
    ../../modules/tailscale.nix
    ../../modules/restic.nix
    ./observability.nix
    ./disk-config.nix
  ];

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
      };
      efi.canTouchEfiVariables = true;
    };

    initrd = {
      supportedFilesystems = [ "zfs" ];
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 2222;
          hostKeys = [ "/etc/ssh/ssh_host_ed25519_key" ];
          authorizedKeys = [
            "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAHiEKQFsgRXTSzCQnDj/V1o8IeorD17qGOJT1oyZSUOlbE2dLeannUed/J1B9nuRniQlQkzwV+jNWONC3yDEM7ogADLYby9t290VYEm5xL+FpxYAdPpz8oXnGtDoITI8ebxqJry0Y2Sc3a/2lkDMKsRzACdEHS94e2VbDA28NsM8kew9A=="
          ];
        };
      };
    };
    supportedFilesystems = [ "zfs" ];
    zfs = {
      forceImportRoot = false;
    };
  };

  networking = {
    hostName = "shuttle";
    hostId = "07661c18";
    useDHCP = true;
  };

  powerManagement = {
    cpuFreqGovernor = "powersave";
    powertop.enable = true;
  };

  systemd.paths.sync-esp = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = [
      "/boot/EFI/Linux"
      "/boot/EFI/nixos"
      "/boot/loader/entries"
      "/boot/loader"
    ];
  };
  systemd.services.sync-esp = {
    description = "Mirror /boot to /boot-fallback";
    unitConfig.RequiresMountsFor = [
      "/boot"
      "/boot-fallback"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.rsync}/bin/rsync -a --delete /boot/ /boot-fallback/";
    };
  };

  services = {

    zfs.autoScrub.enable = true;

    sanoid = {
      enable = true;

      templates.production = {
        frequently = 0;
        hourly = 24;
        daily = 7;
        monthly = 12;
        yearly = 99;

        autosnap = true;
        autoprune = true;
      };

      datasets."rpool/data" = {
        useTemplate = [ "production" ];
        recursive = "zfs"; # Recursively find child datasets
        processChildrenOnly = true; # Snapshot child datasets, but NOT enc/data itself
      };
    };

    tailscale = {
      useRoutingFeatures = "server";
      extraUpFlags = [
        "--advertise-exit-node"
        "--reset"
      ];
    };
  };

  system.stateVersion = "26.05"; # Did you read the comment?
}
