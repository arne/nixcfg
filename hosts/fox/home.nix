{ config, pkgs, lib, launcher, llm-agents, ... }:

{
  imports = [
    ../../home/fish.nix
    ../../home/cli.nix
    ../../home/git.nix
    ../../home/ghostty.nix
    ../../home/helix.nix
    ../../home/firefox.nix
    ../../home/appearance.nix
    ../../home/yazi.nix
    ../../home/pi.nix
    ../../home/hyprpaper.nix
    ../../home/hypridle.nix
    ../../home/hyprlock.nix
    ../../home/dunst.nix
    ../../home/musikcube.nix
  ];

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  home.packages = [
    pkgs.telegram-desktop
    pkgs.nicotine-plus
    launcher.packages.${pkgs.stdenv.hostPlatform.system}.default
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
  ];

  programs.niri.config = builtins.readFile ../../files/niri/config.kdl;
}
