{ pkgs, pkgs-unstable, ... }: {
  home.packages = with pkgs; [
    pkgs-unstable.antigravity-cli
    pkgs-unstable.claude-code
    xld
  ];
}
