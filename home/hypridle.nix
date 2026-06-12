{ config, pkgs, lib, ... }:

let
  cfg = config.my.screenBlank;
in
{
  # hypridle — idle manager for the niri session. Ported from the old
  # ~/.config/hypr/hypridle.conf. services.hypridle installs the package
  # and runs it as a systemd user service bound to graphical-session.target
  # (the same mechanism as services.hyprpaper), so the niri
  # `spawn-at-startup "hypridle"` line is dropped.
  #
  # Idle chain: dim at 5 min → lock at 10 min → screens off at 15 min,
  # plus lock-on-sleep. Uses brightnessctl (in systemPackages), loginctl,
  # and the host's configured screen blank/unblank commands.

  # How the screen is blanked/unblanked at the screen-off timeout (and on
  # sleep). Default is niri's DPMS toggle, which is fine for normal panels.
  # Hosts whose display does not re-train its link after a DPMS-off — fox's
  # Apple Studio Display — override these with a full output disable/enable;
  # see home/studio-display.nix.
  options.my.screenBlank = {
    offCmd = lib.mkOption {
      type = lib.types.str;
      default = "niri msg action power-off-monitors";
      description = "Command run at the screen-off timeout to blank the display.";
    };
    onCmd = lib.mkOption {
      type = lib.types.str;
      default = "niri msg action power-on-monitors";
      description = "Command run on resume (and after sleep) to un-blank the display.";
    };
  };

  config.services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = cfg.onCmd;
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
          on-timeout = cfg.offCmd;
          on-resume = cfg.onCmd;
        }
      ];
    };
  };
}
