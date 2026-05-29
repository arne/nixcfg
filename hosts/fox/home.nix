{ config, pkgs, lib, launcher, llm-agents, ... }:

{
  imports = [
    ../../home/fish.nix
    ../../home/ghostty.nix
    ../../home/helix.nix
    ../../home/firefox.nix
    ../../home/appearance.nix
    ../../home/motd.nix
    ../../home/yazi.nix
    ../../home/pi.nix
    ../../home/hyprpaper.nix
  ];

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user.name = "Arne Skaar Fismen";
      user.email = "arnefismen@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "hx";
    };
  };

  home.packages = [
    pkgs.gh
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
