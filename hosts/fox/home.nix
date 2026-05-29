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
    launcher.packages.${pkgs.system}.default
    llm-agents.packages.${pkgs.system}.pi
  ];

  programs.niri.config = builtins.readFile ../../files/niri/config.kdl;

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload = /home/arne/wallpapers/totoro/totoro025-4x.png
    wallpaper = ,/home/arne/wallpapers/totoro/totoro025-4x.png
    splash = false
    ipc = off
  '';
}
