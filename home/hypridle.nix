{ config, pkgs, lib, ... }:

{
  # hypridle — idle manager for the niri session. Ported from the old
  # ~/.config/hypr/hypridle.conf. services.hypridle installs the package
  # and runs it as a systemd user service bound to graphical-session.target
  # (the same mechanism as services.hyprpaper), so the niri
  # `spawn-at-startup "hypridle"` line is dropped.
  #
  # Idle chain: dim at 5 min → lock at 10 min → screens off at 15 min,
  # plus lock-on-sleep. Uses brightnessctl (in systemPackages), loginctl,
  # and niri's power-on/off-monitors actions.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "niri msg action power-on-monitors";
        ignore_dbus_inhibit = false;
      };

      listener = [
        # Dim the screen after 5 minutes.
        {
          timeout = 300;
          on-timeout = "brightnessctl --class=backlight -s set 10%";
          on-resume = "brightnessctl --class=backlight -r";
        }
        # Lock the screen after 10 minutes.
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
        # Turn off the screen after 15 minutes.
        {
          timeout = 900;
          on-timeout = "niri msg action power-off-monitors";
          on-resume = "niri msg action power-on-monitors";
        }
      ];
    };
  };
}
