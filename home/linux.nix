{ pkgs, ... }: {
  home = {
    homeDirectory = "/home/silvio";

    packages = with pkgs; [

      # For tmux clipboard integration
      wl-clipboard
    ];
  };

  programs.claude-code = {
    enable = true;
  };
}
