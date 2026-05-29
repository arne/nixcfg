{ config, pkgs, lib, ... }:

{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "off";
      splash = false;
      preload = [ "${config.home.homeDirectory}/wallpapers/totoro/totoro025-4x.png" ];
      wallpaper = [ ",${config.home.homeDirectory}/wallpapers/totoro/totoro025-4x.png" ];
    };
  };
}
