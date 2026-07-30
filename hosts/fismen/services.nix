{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## Host-level services beyond Caddy/Incus (those have their own modules).
  ## Inventory of the live box: hosts/fismen/MIGRATION.md.
  ###########################################################################

  imports = [
    ../../modules/services/nyheter.nix
    ../../modules/services/bbs.nix
  ];

  # OIDC client id+secret for nyheter. Tolerant literal path (same pattern as
  # caddy.nix) so the box boots before sops bring-up.
  # TODO after sops bring-up: switch to
  #   config.sops.secrets."nyheter/oidc-env".path
  systemd.services.nyheter.serviceConfig.EnvironmentFile =
    lib.mkForce "-/run/secrets/nyheter/oidc-env";

  ###########################################################################
  ## Teater — teaterfestivalen i Fjaler (teater.fismen.no). Go-app
  ## med SQLite, bygd fra github.com/arne/teater.
  ###########################################################################
  systemd.services.teater = {
    description = "Teater — Teaterfestivalen i Fjaler";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.callPackage ../../pkgs/teater.nix { }}/bin/teaterfestivalen";
      Restart = "always";
      RestartSec = 5;
      DynamicUser = true;
      StateDirectory = "teater";
      WorkingDirectory = "/var/lib/teater";
    };

    environment = {
      PORT = "8084";
      DB_PATH = "/var/lib/teater/festival.db";
    };
  };

  ###########################################################################
  ## beszel-agent — MOVED. This host's agent used to be a hand-rolled unit
  ## here, dialling the old hub over a WebSocket (HUB_URL
  ## https://monitor.fismen.no, KEY+TOKEN from sops beszel/agent-env). Both
  ## ends have changed:
  ##
  ##   * the agent is now the upstream nixpkgs module, configured once for the
  ##     whole fleet in ../../modules/services/beszel.nix (imported from this
  ##     host's configuration.nix), and
  ##   * the hub it reports to is the NixOS one on meow (hosts/meow/beszel.nix,
  ##     https://status.azf.no), reached by the hub dialling fismen on
  ##     :45876 over the tailnet — so no token, and nothing in sops.
  ##
  ## The old hub is still the Incus instance at 10.228.107.118, still fronted
  ## by monitor.fismen.no in ./Caddyfile. It is untouched by this change and
  ## will simply stop hearing from fismen. Retiring it is a separate step:
  ## delete the container, then that vhost. sops still holds the now-unused
  ## beszel/agent-env value; it can be pruned from secrets/fismen.yaml.
  ###########################################################################
}
