{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## Caddy — TLS termination + reverse proxy for the whole fismen estate
  ## (~40 vhosts). The site config is synced verbatim into ./Caddyfile; the
  ## global options block lives here (NixOS owns the generated global block).
  ##
  ## hosts/oink/fismen-interim.nix mirrors this config during the migration
  ## (same Caddyfile, bind-IP rewritten) — keep the two in sync.
  ##
  ## The (cf)-snippet vhosts use DNS-01 ACME via Cloudflare, which needs:
  ##   1. a Caddy build that includes the caddy-dns/cloudflare plugin (below), and
  ##   2. CLOUDFLARE_API_TOKEN in the service environment (sops → EnvironmentFile).
  ###########################################################################

  services.caddy = {
    enable = true;

    # ACME account email (used by both HTTP-01 and DNS-01 vhosts).
    email = "arnefismen@gmail.com";

    # Admin API on the Incus bridge IP, matching the live deployment.
    globalConfig = ''
      admin 10.228.107.1:2019
    '';

    # The site blocks + the (cf)/(tinyauth) snippets.
    extraConfig = builtins.readFile ./Caddyfile;

    # Caddy with the Cloudflare DNS plugin for DNS-01 ACME. v0.2.3 matches the
    # exact plugin version the live (Debian) caddy 2.11.2 was built with.
    # The buildGo126Module override works around a 25.11 nixpkgs bug:
    # withPlugins rebuilds caddy with the DEFAULT Go builder (1.25), but
    # caddy 2.11.3's go.mod requires >= 1.26.3.
    package =
      (pkgs.caddy.override { buildGoModule = pkgs.buildGo126Module; }).withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.3" ];
        hash = "sha256-iTox1dCA6PiEiT1TIX3QWF64waYQpI/s/XCqIeRQ5Sc=";
      };
  };

  systemd.services.caddy = {
    # ANTI-ACME-STORM GATE: never let caddy start against empty cert storage —
    # with ~40 vhosts that would trigger a mass-issuance and brush Let's
    # Encrypt rate limits. The migration runbook rsyncs the previous host's
    # /var/lib/caddy/.local/share/caddy (certificates/ + acme/) into place and
    # then `touch /var/lib/caddy/.storage-seeded` to arm startup.
    unitConfig.ConditionPathExists = "/var/lib/caddy/.storage-seeded";

    # CLOUDFLARE_API_TOKEN for DNS-01; file contains one line:
    #   CLOUDFLARE_API_TOKEN=...
    # Tolerant literal path matching the sops key layout (`-` prefix: a fresh
    # install can boot before sops bring-up; caddy stays gated on
    # .storage-seeded anyway). sops-nix places "caddy/cloudflare-env" exactly
    # here once hosts/fismen/secrets.nix is armed.
    serviceConfig.EnvironmentFile = "-/run/secrets/caddy/cloudflare-env";

    # TAILNET-BIND RACE GATE: the Caddyfile pins `bind 100.102.255.10` (fismen's
    # tailnet IP). tailscaled assigns that address asynchronously *after* it
    # authenticates, so on a cold boot caddy can reach ExecStart before the IP
    # exists and die with "bind: cannot assign requested address". Order after
    # tailscaled and block ExecStart until the address is actually present on a
    # local interface (the caddy module sets no ExecStartPre of its own).
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    serviceConfig.ExecStartPre = pkgs.writeShellScript "wait-for-tailnet-ip" ''
      ip=100.102.255.10
      for _ in $(seq 1 60); do
        ${pkgs.iproute2}/bin/ip -4 -o addr show | ${pkgs.gnugrep}/bin/grep -qw "$ip" && exit 0
        sleep 1
      done
      echo "wait-for-tailnet-ip: $ip not assigned after 60s" >&2
      exit 1
    '';
  };

  # Static-site vhosts serve from /var/www/<site> — migrate those trees over
  # and make sure the caddy user can read them.
  # (bases, lageriet, nytta, chess, totalfrihet, themebases, arne, tjue)

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  # HTTP/3
  networking.firewall.allowedUDPPorts = [ 443 ];
}
