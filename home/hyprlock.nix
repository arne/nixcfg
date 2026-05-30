{ config, pkgs, lib, ... }:

{
  # hyprlock — lock screen for the niri session. Ported from the old
  # ~/.config/hypr/hyprlock.conf. programs.hyprlock installs the package
  # and writes the config; it's invoked on demand (the niri Super+Alt+L
  # bind and hypridle's lock_cmd / loginctl lock-session), so there's no
  # service to enable here.
  #
  # Totoro wallpaper (blurred), centred password field in the bases
  # palette, big clock + date. The wallpaper is a loose file under
  # ~/wallpapers (not Nix-managed), referenced by absolute path like
  # hyprpaper does. Font is the installed JetBrainsMono Nerd Font.
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 0;
        no_fade_in = false;
      };

      background = {
        monitor = "";
        path = "${config.home.homeDirectory}/wallpapers/totoro/totoro025.jpg";
        blur_passes = 3;
        blur_size = 8;
        contrast = 0.9;
        brightness = 0.7;
      };

      input-field = {
        monitor = "";
        size = "280, 48";
        position = "0, -120, relative";
        halign = "center";
        valign = "center";

        outline_thickness = 2;
        dots_size = 0.25;
        dots_spacing = 0.4;
        dots_center = true;

        outer_color = "rgba(0, 0, 0, 0)";
        inner_color = "rgba(20, 20, 20, 0.65)";
        font_color = "rgb(220, 220, 220)";
        fade_on_empty = false;
        placeholder_text = "<i>Password</i>";
        check_color = "rgb(74, 159, 130)";
        fail_color = "rgb(217, 80, 80)";
        fail_text = "<i>$FAIL</i>";

        rounding = 8;
      };

      label = [
        # Clock.
        {
          monitor = "";
          text = ''cmd[update:1000] echo "$(date +'%H:%M')"'';
          color = "rgba(230, 230, 230, 0.95)";
          font_size = 96;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 200";
          halign = "center";
          valign = "center";
        }
        # Date.
        {
          monitor = "";
          text = ''cmd[update:60000] echo "$(date +'%A, %B %-d')"'';
          color = "rgba(200, 200, 200, 0.85)";
          font_size = 18;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 110";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
