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
  ## beszel-agent — host metrics for the beszel hub (monitor.fismen.no, an
  ## incus instance). nixpkgs ships the package; KEY/TOKEN go in the env file
  ## (sops: beszel/agent-env):
  ##   KEY=ssh-ed25519 ...
  ##   TOKEN=...
  ###########################################################################
  systemd.services.beszel-agent = {
    description = "Beszel Agent";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    environment = {
      PORT = "45876";
      HUB_URL = "https://monitor.fismen.no";
    };

    serviceConfig = {
      ExecStart = "${pkgs.beszel}/bin/beszel-agent";
      EnvironmentFile = "-/run/secrets/beszel/agent-env"; # TODO: sops path
      DynamicUser = true;
      StateDirectory = "beszel-agent";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
