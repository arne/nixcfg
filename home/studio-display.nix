{ config, pkgs, lib, ... }:

let
  # fox drives a single Apple Studio Display over USB4. Two quirks need
  # handling, both solved by resolving the connector at runtime by make/model
  # rather than by DP number — the DP connector numbers drift across reboots
  # (they have already gone DP-5/6 → DP-7/8 once, which stranded every
  # workspace on the phantom output and left the desktop apparently empty):
  #
  #   1. The panel does not re-train its DisplayPort link after a DPMS-off, so
  #      niri's power-off/power-on-monitors leave it black on wake. A full
  #      output disable/enable forces a modeset that re-trains the link.
  #   2. The display also exposes a phantom secondary DP stream (no EDID, so
  #      niri reports make "Unknown") that niri treats as a tiny output and
  #      lets steal workspaces. We turn every Unknown-make output off.
  #
  # `niri` is on PATH inside the niri systemd user session (hypridle already
  # relies on this); jq is pulled in explicitly.
  studio-display-toggle = pkgs.writeShellApplication {
    name = "studio-display-toggle";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      # Usage: studio-display-toggle off|on   (run with "on" at session start)
      action="''${1:-on}"

      conn=$(niri msg --json outputs \
        | jq -r '[to_entries[]
                  | select(.value.make == "Apple Computer Inc"
                           and .value.model == "StudioDisplay")
                  | .key][0] // empty')

      if [ -n "$conn" ]; then
        niri msg output "$conn" "$action"
      fi

      if [ "$action" = "on" ]; then
        # Disable phantom secondary streams (no EDID) so they cannot grab
        # workspaces while the real output is toggled off and back on.
        niri msg --json outputs \
          | jq -r 'to_entries[] | select(.value.make == "Unknown") | .key' \
          | while read -r out; do
              niri msg output "$out" off || true
            done
      fi
    '';
  };
in
{
  home.packages = [ studio-display-toggle ];

  # The idle screen-off (home/hypridle.nix) uses the modeset toggle, not DPMS.
  my.screenBlank.offCmd = "${studio-display-toggle}/bin/studio-display-toggle off";
  my.screenBlank.onCmd = "${studio-display-toggle}/bin/studio-display-toggle on";

  # Assert the phantom off (and the real output on) once the niri session is
  # up — same systemd-user-service-on-graphical-session.target mechanism that
  # hypridle/hyprpaper use, so no niri spawn-at-startup is needed. Without this
  # the phantom is live from boot until the first idle/wake cycle.
  systemd.user.services.studio-display-outputs = {
    Unit = {
      Description = "Disable Apple Studio Display phantom output(s)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${studio-display-toggle}/bin/studio-display-toggle on";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
