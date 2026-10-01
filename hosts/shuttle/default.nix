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
    ../../modules/network-wait.nix
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

  # Suspend after an hour of inactivity. Any login (local tty or ssh) keeps the
  # machine awake indefinitely, even when idle; the remaining checks stop us
  # from suspending on top of a running backup or an active Samba client. An
  # RTC alarm is armed before the nightly restic timers so the box wakes up for
  # them; every other timer is Persistent= and catches up after a wake. Those
  # catch-up runs happen in the same second as the resume, so the ones that
  # need the network wait on wait-for-network.service first -- see
  # modules/network-wait.nix.
  services.autosuspend = {
    enable = true;

    settings = {
      interval = 60; # check once a minute
      idle_time = 900; # all checks quiet for 15min -> suspend
      min_sleep_time = 900; # don't suspend if we'd wake again within 15min
      wakeup_delta = 60; # wake 1min before a scheduled wakeup
    };

    checks = {
      # Any login, local or over ssh: both land in utmp.
      Users = {
        name = ".*";
        terminal = ".*";
        host = ".*";
      };

      # ssh activity without a login session: scp/rsync/git, port forwards.
      SshConnections = {
        class = "ActiveConnection";
        ports = "22";
      };

      # Open Samba sessions.
      Smb = { };

      # Long-running jobs that must not be cut off mid-flight.
      Jobs = {
        class = "Processes";
        processes = "restic,mbsync,rsync,zpool";
      };

      Load.threshold = 1.0;
    };

    wakeups = {
      Backups = {
        class = "SystemdTimer";
        match = "restic-backups-.*";
      };
    };
  };

  # autosuspend arms the RTC alarm by running its wakeup_cmd through a shell,
  # and that command is itself `sh -c '...'`. The unit's PATH only carries
  # samba, coreutils, findutils, grep, sed and systemd -- no shell -- so the
  # inner `sh` was never found and arming failed with exit 127, leaving
  # /sys/class/rtc/rtc0/wakealarm unset. The box then slept straight through
  # the 03:00 backups.
  systemd.services.autosuspend.path = [ pkgs.bash ];

  services = {

    zfs.autoScrub.enable = true;

    sanoid = {
      enable = true;

      templates.production = {
        frequently = 4;
        hourly = 24;
        daily = 7;
        weekly = 5;
        monthly = 12;
        yearly = 99;

        autosnap = true;
        autoprune = true;
      };

      datasets."rpool/data" = {
        useTemplate = [ "production" ];
        # One atomic `zfs snapshot -r` covering every child dataset.
        # Must not be combined with processChildrenOnly: zfs-native recursion
        # acts on this dataset, so excluding it leaves sanoid nothing to do.
        recursive = "zfs";
      };

      datasets."rpool/var" = {
        useTemplate = [ "production" ];
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
