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
        processes = "restic,mbsync,rsync,zpool,syncoid";
      };

      Load.threshold = 1.0;
    };

    wakeups = {
      Backups = {
        class = "SystemdTimer";
        match = "restic-backups-.*";
      };

      Replication = {
        class = "SystemdTimer";
        match = "syncoid-.*";
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

  # The SATA SSD is an external backup disk holding rpool_backup -- out of the
  # boot path and absent from disk-config.nix -- unlocked in stage 2 from a
  # static sops key rather than by the initrd. sops secrets are installed by
  # initrd-nixos-activation.service before switch-root, so the key file is
  # already there when systemd-cryptsetup runs.
  #
  # `nofail` is what makes this optional: the generator then only Wants= the
  # unit from cryptsetup.target without ordering it Before=, so an unplugged
  # disk neither delays nor fails the boot.
  #
  # The disk carries one GPT partition labelled samsung-860-4tb-luks and nothing
  # else. by-partlabel lives in the GPT, so it travels with the disk and stays
  # correct once this moves into a USB enclosure. The label names the drive
  # itself, so swapping in a different disk means relabelling here too; the
  # mapper name stays role-based and survives such a swap.
  sops.secrets.sata_luks_key = { };

  environment.etc.crypttab.text = ''
    crypt-backup /dev/disk/by-partlabel/samsung-860-4tb-luks ${config.sops.secrets.sata_luks_key.path} luks,nofail,discard,no-read-workqueue,no-write-workqueue
  '';

  # Import the backup pool once its disk is unlocked. Deliberately not
  # boot.zfs.extraPools: that unit is requiredBy zfs-import.target and retries
  # for 60s before failing, so every boot without the disk would stall and then
  # fail. Here a missing pool is a clean no-op instead, which also covers the
  # disk being present but the unlock having failed.
  #
  # -N imports without mounting. -R sets an altroot so that even a stray
  # `zfs mount -a` puts these datasets under /run/rpool_backup rather than on
  # top of the live ones; it also implies cachefile=none, keeping the pool out
  # of /etc/zfs/zpool.cache.
  systemd.services.import-rpool-backup = {
    description = "Import the external ZFS backup pool";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-cryptsetup@crypt\\x2dbackup.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "import-rpool-backup" ''
        set -eu
        zpool="${config.boot.zfs.package}/sbin/zpool"

        if "$zpool" list -H -o name rpool_backup >/dev/null 2>&1; then
          echo "rpool_backup is already imported"
          exit 0
        fi

        # Only attempt the import if the pool is actually visible; otherwise
        # this is a no-op so the unit stays green with the disk detached.
        if ! "$zpool" import 2>/dev/null | grep -qE '^[[:space:]]*pool: rpool_backup$'; then
          echo "rpool_backup is not attached, nothing to do"
          exit 0
        fi

        exec "$zpool" import -N -R /run/rpool_backup rpool_backup
      '';
    };
  };

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

      # The backup pool needs sanoid as well, but purely as a pruner: snapshots
      # arrive there by replication, so autosnap is off. It reuses the production
      # template rather than declaring its own retention, which guarantees the
      # target keeps every snapshot type at least as long as the source does.
      # That matters twice over: any type omitted from a template defaults to 0,
      # and sanoid immediately destroys types set to 0 -- and pruning the target
      # harder than the source could take the last common snapshot, which with no
      # --force-delete on the syncoid side would stop replication dead.
      #
      # recursive = true prunes each child in its own right; the zfs-native
      # recursion used on the source is only about taking atomic snapshots, which
      # is not happening here. A detached disk just logs one "dataset does not
      # exist" line per entry and sanoid carries on.
      datasets."rpool_backup/data" = {
        useTemplate = [ "production" ];
        autosnap = false;
        recursive = true;
      };

      datasets."rpool_backup/var" = {
        useTemplate = [ "production" ];
        autosnap = false;
      };
    };

    # Replicate the sanoid-snapshotted datasets onto the external backup pool.
    # --no-sync-snap sends sanoid's existing snapshots instead of creating
    # syncoid's own, so the two commands below mirror the sanoid datasets above.
    #
    # recvOptions: -u never mounts on receive (an unprivileged zfs recv cannot
    # mount anyway), and -x mountpoint drops the source's mountpoint from the
    # stream so received datasets inherit mountpoint=none from rpool_backup
    # instead of arriving pointed at the live /data/* paths.
    #
    # Note the absence of --force-delete: if the last common snapshot is ever
    # lost, replication should fail loudly rather than quietly destroying the
    # backup and resending 1.5T.
    syncoid = {
      enable = true;
      interval = "02:00"; # an hour ahead of the restic timers
      commonArgs = [ "--no-sync-snap" ];

      # Only run when the backup disk is attached and unlocked. This has to be a
      # unit Condition rather than ExecCondition: the module sets
      # RootDirectory=/run/syncoid/<name> with RootDirectoryStartOnly=true, whose
      # exemption covers ExecStartPre/ExecStopPost but not ExecCondition, so an
      # ExecCondition gets chrooted into a directory that does not exist yet and
      # dies at CHDIR before running. PID 1 evaluates Conditions outside any
      # sandbox. crypt-backup is our own mapper name from crypttab, not a backing
      # device path, so it stays correct once the disk moves to USB.
      service = {
        after = [ "import-rpool-backup.service" ];
        requires = [ "import-rpool-backup.service" ];
        unitConfig.ConditionPathExists = "/dev/mapper/crypt-backup";
      };

      commands = {
        "rpool/data" = {
          target = "rpool_backup/data";
          recursive = true;
          recvOptions = "u x mountpoint";
        };
        "rpool/var" = {
          target = "rpool_backup/var";
          recvOptions = "u x mountpoint";
        };
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
