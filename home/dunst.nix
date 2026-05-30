{ config, pkgs, lib, ... }:

{
  # dunst — notification daemon for the niri session. Ported from the old
  # ~/.config/dunst/dunstrc. services.dunst installs the package and runs
  # it as a systemd user service (bound to graphical-session.target, like
  # hyprpaper/hypridle), so the niri `spawn-at-startup "dunst"` line is
  # dropped.
  #
  # bases-palette styling (matches ghostty/helix), IBM Plex Sans 11 (added
  # to fonts.packages in configuration.nix), top-centre, no icons, title +
  # body on one line, per-urgency colours.
  #
  # The old config's `[log_all]` rule (which shelled out to a
  # ~/.local/bin/log-notification helper for the launcher's notification
  # history) is intentionally omitted — that script wasn't in the backup.
  services.dunst = {
    enable = true;
    settings = {
      global = {
        monitor = 0;
        follow = "mouse";

        # geometry
        width = "(200, 600)";
        height = "(0, 50)";
        origin = "top-center";
        offset = "(0, 4)";
        notification_limit = 5;
        gap_size = 6;

        # shape — corner_radius matches niri geometry-corner-radius (8)
        frame_width = 1;
        frame_color = "#3a3630";
        corner_radius = 8;

        # spacing
        padding = 4;
        horizontal_padding = 18;
        text_icon_padding = 0;
        separator_height = 0;

        # font + layout: title and body on one line
        font = "IBM Plex Sans 11";
        markup = "full";
        format = "<b>%s</b>  %b";
        alignment = "center";
        vertical_alignment = "center";
        word_wrap = false;
        ellipsize = "end";
        ignore_newline = true;
        line_height = 0;

        # no icons
        icon_position = "off";
        min_icon_size = 0;
        max_icon_size = 0;
        enable_recursive_icon_lookup = false;

        # behaviour
        indicate_hidden = true;
        transparency = 0;
        sort = true;
        idle_threshold = 120;
        show_age_threshold = 60;
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = false;
        sticky_history = true;
        history_length = 50;

        mouse_left_click = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };

      urgency_low = {
        background = "#141210";
        foreground = "#857e75";
        frame_color = "#2c2924";
        timeout = 4;
      };

      urgency_normal = {
        background = "#141210";
        foreground = "#ede8de";
        frame_color = "#3a3630";
        timeout = 6;
      };

      urgency_critical = {
        background = "#141210";
        foreground = "#ede8de";
        frame_color = "#d95050";
        timeout = 0;
      };
    };
  };
}
