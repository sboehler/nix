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
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # lanzaboote = {
    #   enable = true;
    #   pkiBundle = "/var/lib/sbctl";
    # };

    initrd = {
      supportedFilesystems = [ "zfs" ];
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 2222;
          hostKeys = [ "/etc/ssh/ssh_host_ed25519_key" ];
          authorizedKeys = config.users.users.silvio.openssh.authorizedKeys.keys;
        };
      };
      # When the following line is on, root can't log in:
      # systemd.users.root.shell = "${pkgs.systemd}/bin/systemd-tty-ask-password-agent";
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

  # The RTL8156 USB-Ethernet adapter (main NIC) defaults to waking on any
  # PHY/unicast/multicast/broadcast activity, not just a magic packet. On a
  # busy LAN that means it resumes from suspend within seconds of going to
  # sleep. Restrict wake sources to magic-packet only, so WOL still works
  # but ambient broadcast/multicast traffic no longer wakes it.
  systemd.network.links."10-rtl8156" = {
    matchConfig.MACAddress = "3c:49:37:05:5f:9b";
    linkConfig.WakeOnLan = "magic";
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
