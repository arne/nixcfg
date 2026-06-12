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
  ];

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  home.packages = [
    pkgs.telegram-desktop
    launcher.packages.${pkgs.stdenv.hostPlatform.system}.default
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
  ];

  # Per-host wallpaper: a scenic Studio Ghibli still — the coastal bay seen from
  # the hilltop in "When Marnie Was There" (distinct from fox's Totoro).
  # Lanczos-upscaled (no AI — keeps the hand-painted softness) and cover-cropped
  # to the panel's native 2560x1600, so hyprpaper renders it 1:1 with no runtime
  # scaling. The image lives in ~/wallpapers (not the repo, same as fox's).
  # Overrides the mkDefault in home/hyprpaper.nix.
  services.hyprpaper.settings = {
    preload = [ "${config.home.homeDirectory}/wallpapers/marnie/marnie006-2560x1600.png" ];
    wallpaper = [ ",${config.home.homeDirectory}/wallpapers/marnie/marnie006-2560x1600.png" ];
  };

  programs.niri.config =
    builtins.readFile ../../files/niri/common.kdl
    + builtins.readFile ../../files/niri/air.kdl;
}
