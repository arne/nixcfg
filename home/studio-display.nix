{ config, pkgs, lib, ... }:

let
  # fox drives a single Apple Studio Display over USB4. The facts on the
  # ground (verified against EDID dumps and the niri source, 2026-06):
  #
  #   * The USB4 link occasionally drops and re-enumerates, renumbering the
  #     DP connectors (DP-5/6 → DP-7/8 has happened). Connector names are
  #     therefore useless as config keys; the EDID identity is stable and
  #     niri matches outputs by "<make> <model> <serial>" everywhere a
  #     connector name is accepted (niri-config output.rs `matches()`).
  #
  #   * The display structurally exposes a SECOND DP stream (DisplayID tiled
  #     topology, the pre-DSC dual-SST legacy). DP tunnel 1 negotiates the
  #     full 5120x2880@60 single-stream via DSC; tunnel 2 stays connected
  #     with a malformed, zero-padded copy of the EDID that libdisplay-info
  #     rejects — so niri sees make/model/serial as missing and reports
  #     "Unknown". Such an output can NOT be matched in the declarative
  #     config (niri deliberately refuses identifier matching when all EDID
  #     fields are absent), so a runtime guard is the only place to disable
  #     it. It reappears on every boot and after every link re-enumeration —
  #     hence an event-driven guard, not a session-start oneshot.
  #
  #   * The panel does not re-train its DP link after plain DPMS-off, so the
  #     idle blank uses a full output disable/enable (modeset) instead of
  #     power-off-monitors. Worth retesting on kernel bumps; if a future
  #     kernel re-trains correctly, drop offCmd/onCmd back to the
  #     my.screenBlank defaults and the toggle below disappears.
  #
  # The serial is this specific panel's EDID serial. A replacement display
  # changes it: `niri msg outputs` shows the new one.
  displayId = "Apple Computer Inc StudioDisplay 0xDF8E29CD";

  # Idle blank/unblank for the real display, addressed by stable identity.
  studio-display-toggle = pkgs.writeShellApplication {
    name = "studio-display-toggle";
    text = ''
      # Usage: studio-display-toggle off|on
      niri msg output "${displayId}" "''${1:-on}"
    '';
  };

  # Disable any output niri could not identify (no make/model/serial — on
  # this machine that is exactly the Studio Display's vestigial second
  # stream). Triggered by the niri event stream: WorkspacesChanged fires
  # whenever output topology changes (session start, hotplug, link-drop
  # re-enumeration), which is precisely when the phantom can (re)appear.
  studio-display-guard = pkgs.writeShellApplication {
    name = "studio-display-guard";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      sweep() {
        niri msg --json outputs \
          | jq -r 'to_entries[]
                   | select(.value.make == "Unknown"
                            and .value.model == "Unknown")
                   | .key' \
          | while read -r out; do
              niri msg output "$out" off || true
            done
      }
      sweep
      niri msg --json event-stream | while read -r ev; do
        case "$ev" in
          *WorkspacesChanged*) sweep ;;
        esac
      done
    '';
  };
in
{
  home.packages = [ studio-display-toggle ];

  # The idle screen-off (home/hypridle.nix) uses the modeset toggle, not
  # DPMS — see the link re-training note above.
  my.screenBlank.offCmd = "${studio-display-toggle}/bin/studio-display-toggle off";
  my.screenBlank.onCmd = "${studio-display-toggle}/bin/studio-display-toggle on";

  systemd.user.services.studio-display-guard = {
    Unit = {
      Description = "Disable Apple Studio Display phantom output (event-driven)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${studio-display-guard}/bin/studio-display-guard";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
