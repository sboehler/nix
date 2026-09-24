{ inputs, pkgs, ... }:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
  ];
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.silvio = {
    imports = [
      ../home/common.nix
      ../home/linux.nix
    ];
  };
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };

  time.timeZone = "Europe/Amsterdam";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "de_CH.UTF-8";
      LC_MONETARY = "de_CH.UTF-8";
      LC_MEASUREMENT = "de_CH.UTF-8";
      LC_NUMERIC = "de_CH.UTF-8";
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  nix = {
    gc.automatic = true;
    optimise.automatic = true;
    settings = {
      trusted-users = [
        "root"
        "silvio"
      ];
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  # https://github.com/mic92/sops-nix#sops-nix
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      ssh_config = {
        format = "binary";
        sopsFile = ../secrets/ssh_config.text;
        owner = "root";
        mode = "0555";
      };
    };
  };

  environment = {
    systemPackages = with pkgs; [
      dnsutils
      jnettop
      pciutils
    ];

    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  programs = {
    zsh = {
      enable = true;
    };
    htop = {
      enable = true;
    };
    mtr.enable = true;
    iftop.enable = true;
    git.enable = true;
    ssh = {
      startAgent = true;
    };
    nix-ld.enable = true;

    # Optional: ensure neovim is installed system-wide
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };

  services = {
    openssh.enable = true;
    fwupd.enable = true;
    chrony.enable = true;
  };

  networking = {
    firewall.enable = true;
  };
}
