{ config, pkgs, lib, ... }:

let
  fleet = pkgs.callPackage ../../pkgs/fleet.nix { };
in
{
  ###########################################################################
  ## fleet.azf.no — the `fleet` status table as a web page.
  ##
  ## An hourly oneshot renders `fleet web` (HTML styled after azf.no) to a
  ## static file; Caddy serves it (vhost in ./caddy.nix). The static file IS
  ## the cache the user asked for: the page loads instantly and the SSH
  ## probing happens off the request path, at most once an hour.
  ##
  ## Runs as arne, because that is who can reach the fleet: `fleet` SSHes each
  ## host as arne (the shared key in modules/ssh-keys.nix) and reads the flake
  ## at /home/arne/nixcfg for the target revision. The probe uses
  ## StrictHostKeyChecking=accept-new so a never-before-seen host can't stall
  ## the unit on a host-key prompt.
  ###########################################################################
  systemd.services.fleet-web = {
    description = "Render the fleet status page (fleet.azf.no)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # The local (self) probe shells out to nixos-version, sed and bash, which
    # live in the system profile — a downed host is probed over SSH and finds
    # them in the remote's own PATH, but meow probes itself locally, so the
    # unit needs the system profile on PATH (also covers mv in ExecStart).
    path = [ "/run/current-system/sw" ];
    serviceConfig = {
      Type = "oneshot";
      User = "arne";
      Group = "users";
      Environment = [
        "HOME=/home/arne"
        "FLEET_FLAKE=/home/arne/nixcfg"
      ];
      # systemd creates/owns /var/lib/fleet-web (arne, 0755); Caddy reads the
      # world-readable index.html from it.
      StateDirectory = "fleet-web";
      StateDirectoryMode = "0755";
      # Render to a temp file and rename, so a slow probe never serves a
      # half-written page.
      ExecStart = pkgs.writeShellScript "fleet-web-render" ''
        set -euo pipefail
        dst=/var/lib/fleet-web
        ${fleet}/bin/fleet web > "$dst/.index.html.tmp"
        mv -f "$dst/.index.html.tmp" "$dst/index.html"
      '';
    };
  };

  systemd.timers.fleet-web = {
    description = "Hourly fleet status render";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";        # first render shortly after boot
      OnUnitActiveSec = "1h";    # then hourly
      Persistent = true;         # catch up a missed run after downtime
    };
  };
}
