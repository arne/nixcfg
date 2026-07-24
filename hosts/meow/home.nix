{ config, pkgs, lib, ... }:

{
  # Headless home box — CLI modules only (no GUI: appearance / ghostty /
  # firefox / niri are intentionally excluded, same shape as fismen/oink).
  imports = [
    ../../home/fish.nix
    ../../home/cli.nix
    ../../home/git.nix
    ../../home/claude.nix
    ../../home/helix.nix
    ../../home/yazi.nix
  ];

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;
}
