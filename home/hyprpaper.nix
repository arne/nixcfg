{ config, pkgs, lib, ... }:

{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "off";
      splash = false;
      # Default wallpaper (fox's Totoro). Hosts override preload/wallpaper with
      # their own image at normal priority — see hosts/air/home.nix.
      preload = lib.mkDefault [ "${config.home.homeDirectory}/wallpapers/totoro/totoro025-4x.png" ];
      wallpaper = lib.mkDefault [ ",${config.home.homeDirectory}/wallpapers/totoro/totoro025-4x.png" ];
    };
  };
}
