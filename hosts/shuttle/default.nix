{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../system/nixos.nix
    ../../modules/mbsync.nix
    ../../modules/user.nix
    ../../modules/fileserver.nix
    ../../modules/withings-sync.nix
    ../../modules/tailscale.nix
    ../../modules/restic.nix
    ./observability.nix
  ];

  boot = {
    loader = {
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        configurationLimit = 5;
        mirroredBoots = [
          {
            devices = [ "/dev/disk/by-id/ata-Samsung_SSD_860_QVO_4TB_S4CXNF0M310137V" ];
            path = "/boot";
          }
          {
            devices = [ "/dev/disk/by-id/nvme-CT4000P3SSD8_2310E6B97FF9" ];
            path = "/boot2";
          }
        ];
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
      devNodes = "/dev/disk/by-id";
      requestEncryptionCredentials = true;
      extraPools = [ "rpool" ];
      forceImportRoot = true;
    };
  };

  # boot.initrd.postDeviceCommands = lib.mkAfter ''
  # zfs rollback -r rpool/local/root@blank
  # '';

  networking = {
    hostName = "shuttle";
    hostId = "07661c18";
    useDHCP = true;
  };

  powerManagement = {
    cpuFreqGovernor = "powersave";
    powertop.enable = true;
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

      datasets."rpool/enc/data" = {
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
