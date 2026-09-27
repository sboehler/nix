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
    ./disk-config.nix
    ../../system/nixos.nix
    ../../modules/tailscale.nix
    ../../modules/user.nix
  ];

  home-manager.users.silvio = {
    programs = {
      firefox = {
        enable = true;
      };
    };
  };

  fonts.fontconfig = {
    enable = true;
    antialias = true; # Set to false to disable anti-aliasing
    hinting.enable = true;
    hinting.style = "slight"; # Options include: "none", "slight", "medium", "full"
    subpixel.rgba = "rgb"; # Subpixel rendering: "rgb", "bgr", "vrgb", "vbgr", or "none"
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      cups-browsed
    ];
  };

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
      };
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    kernel.sysctl = {
      # Prevent ARP flux on dual-homed subnets
      "net.ipv4.conf.all.arp_ignore" = 1;
      "net.ipv4.conf.all.arp_announce" = 2;
      "net.ipv4.conf.default.arp_ignore" = 1;
      "net.ipv4.conf.default.arp_announce" = 2;
      # Prevent reverse path packet dropping
      "net.ipv4.conf.all.rp_filter" = 2;
      "net.ipv4.conf.default.rp_filter" = 2;
    };
    kernelParams = [
      # Compress the hibernation snapshot (saves write/read time on SSDs)
      "hibernate.compress=1"

      # Preferred *upper bound* on the hibernation image, in bytes; 0 means
      # "make the image as small as possible". Note this does not impose a
      # 40-50% limit -- ~40% of RAM (2/5 of totalram) is the kernel's own
      # default, which this value overrides downwards. A smaller image means
      # less disk I/O writing and reading the snapshot, at the cost of more
      # page reclaim before the snapshot is taken.
      "image_size=0"

      # Bitwarden Desktop holds an open memfd_secret() fd for its entire lifetime.
      # The kernel refuses hibernation while any secretmem user exists, because
      # secretmem pages are deliberately unmappable and so cannot be written into
      # the hibernation image (hibernation_available() checks !secretmem_active()).
      # Symptom: /sys/power/disk reads "[disabled]", /sys/power/state loses "disk",
      # and logind reports CanHibernate/CanSuspendThenHibernate = "na" -- which in
      # turn makes PowerDevil's SleepMode=3 battery profile silently do nothing on
      # lid close, so the laptop stays awake on battery. Disabling secretmem makes
      # memfd_secret() return -ENOSYS so callers fall back to ordinary memory.
      # Trade-off: those secrets may now appear in the hibernation image, which
      # lives on /.swap/swapfile on the LUKS-encrypted volume (encrypted at rest).
      "secretmem.enable=0"
    ];
  };

  systemd.sleep.settings.Sleep = {
    AllowSuspendThenHibernate = "yes";
  };

  environment.systemPackages = with pkgs; [
    bitwarden-desktop
    digikam
    google-chrome
    quota
    vscode

    # For Plasma network interface view
    aha
  ];

  networking = {
    hostName = "thinkpad";
    hostId = "63eea51a";
  };

  services = {
    hardware.bolt.enable = true;

    btrfs = {
      autoScrub = {
        enable = true;
      };
    };

    fprintd = {
      enable = true;
    };

    desktopManager.plasma6.enable = true;

    # Default display manager for Plasma
    displayManager.plasma-login-manager.enable = true;
  };

  networking = {
    networkmanager = {
      enable = true;
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  system.stateVersion = "26.05"; # Did you read the comment?
}
