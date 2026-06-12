{ config, pkgs, lib, ... }:

{
  # Headless server home — CLI modules only (no GUI: appearance / ghostty /
  # firefox / niri are intentionally excluded).
  imports = [
    ../../home/fish.nix
    ../../home/cli.nix
    ../../home/git.nix
    ../../home/helix.nix
    ../../home/yazi.nix
  ];

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;
}
