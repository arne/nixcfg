{ config, pkgs, lib, launcher, llm-agents, ... }:

{
  imports = [
    ../../home/fish.nix
    ../../home/cli.nix
    ../../home/git.nix
    ../../home/ghostty.nix
    ../../home/helix.nix
    ../../home/tmux.nix
    ../../home/firefox.nix
    ../../home/appearance.nix
    ../../home/yazi.nix
    ../../home/pi.nix
    ../../home/hyprpaper.nix
  ];

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  home.packages = [
    pkgs.musikcube
    pkgs.telegram-desktop
    pkgs.nicotine-plus
    # Per-user session components — niri spawns these at startup (hyprpaper
    # is managed by services.hyprpaper instead, see ../../home/hyprpaper.nix).
    pkgs.hypridle
    pkgs.hyprlock
    pkgs.dunst
    launcher.packages.${pkgs.system}.default
    llm-agents.packages.${pkgs.system}.pi
  ];

  programs.niri.config = builtins.readFile ../../files/niri/config.kdl;
}
