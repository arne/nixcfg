{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## FISMEN-INTERIM — temporary home for the fismen estate while that box is
  ## reinstalled with NixOS. This module + the FISMEN-INTERIM-marked preseed
  ## blocks in ./incus.nix (bridge incusbr1, profile fismen) are the entire
  ## footprint; to decommission after the move-back:
  ##   1. drop the ./fismen-interim.nix import in ./configuration.nix
  ##   2. delete this file + the marked preseed blocks in ./incus.nix
  ##   3. runbook: delete the copied instances, incusbr1, /var/www, the caddy
  ##      state dir, and the `fismen`/`oink` incus remotes on both ends
  ## (The virtualisation.incus.package bump in ./incus.nix is PERMANENT —
  ## the daemon DB upgrade is one-way.)
  ##
  ## See hosts/fismen/MIGRATION.md for the full inventory + runbook.
  ###########################################################################

  imports = [
    ../../modules/services/nyheter.nix
    ../../modules/services/bbs.nix
  ];

  #### Caddy — mirrors hosts/fismen/caddy.nix, sharing the same Caddyfile.
  #### The two tailnet-bound vhosts (vault.fismen.no, ai.azf.no) bind fismen's
  #### tailnet IP in the source file; rewrite it to OINK's tailnet IP here.
  services.caddy = {
    enable = true;
    email = "arnefismen@gmail.com";

    # Admin API on the (interim) bridge IP — incusbr1 owns 10.228.107.1, so
    # the address works unchanged from the live deployment.
    globalConfig = ''
      admin 10.228.107.1:2019
    '';

    extraConfig = builtins.replaceStrings
      [ "bind 100.102.255.10" ] # fismen's tailnet IP
      [ "bind 100.78.72.66" ]  # oink's tailnet IP
      (builtins.readFile ../fismen/Caddyfile);

    # Same plugin build as hosts/fismen/caddy.nix (keep the hash + the
    # buildGo126Module workaround in sync — see the comment there).
    package =
      (pkgs.caddy.override { buildGoModule = pkgs.buildGo126Module; }).withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.3" ];
        hash = "sha256-e9GJDsvFTLEMkrmBz0kB4omUeaMbhhAt4CnP4q31FE4=";
      };
  };

  systemd.services.caddy = {
    # ANTI-ACME-STORM GATE — same as hosts/fismen/caddy.nix: caddy refuses to
    # start until the live host's cert storage has been rsynced into
    # /var/lib/caddy/.local/share/caddy and `.storage-seeded` touched.
    # Otherwise ~40 vhosts would mass-reissue and brush LE rate limits.
    unitConfig.ConditionPathExists = "/var/lib/caddy/.storage-seeded";
    serviceConfig.EnvironmentFile =
      config.sops.secrets."caddy/cloudflare-env".path;
  };

  #### Secrets (added to secrets/oink.yaml with `sops secrets/oink.yaml`):
  ####   caddy/cloudflare-env  — CLOUDFLARE_API_TOKEN=...   (DNS-01 ACME)
  ####   nyheter/oidc-env      — OIDC_CLIENT_ID=... + OIDC_CLIENT_SECRET=...
  sops.secrets."caddy/cloudflare-env" = { mode = "0400"; };
  sops.secrets."nyheter/oidc-env" = { mode = "0400"; };

  systemd.services.nyheter.serviceConfig.EnvironmentFile =
    config.sops.secrets."nyheter/oidc-env".path;

  #### Firewall — public ingress for the estate (bbs :2222 is opened by its
  #### module). oink otherwise only exposes :22.
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 443 ]; # HTTP/3

  # Migrated containers need DHCP/DNS from dnsmasq on the new bridge —
  # mirror of the incusbr0 rules in ./incus.nix.
  networking.firewall.interfaces.incusbr1.allowedUDPPorts = [ 53 67 ];
  networking.firewall.interfaces.incusbr1.allowedTCPPorts = [ 53 ];
}
