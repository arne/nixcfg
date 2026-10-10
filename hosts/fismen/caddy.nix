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
    #
    # grace_period bounds how long caddy drains on SIGTERM. Unset, it drains
    # indefinitely, and the nb.fismen.no gRPC routes hold streams open for as
    # long as a peer is connected: on 2026-10-10 a routine `nixos-rebuild
    # switch` sent SIGTERM, caddy never finished draining, systemd SIGKILLed it
    # at the 5s TimeoutStopSec, the unit landed in `failed` (Result: timeout)
    # and the activation never started it again — taking all ~45 vhosts down,
    # not just NetBird. This MUST stay below the module's TimeoutStopSec=5s or
    # it changes nothing: the point is for caddy to exit on its own first.
    globalConfig = ''
      admin 10.228.107.1:2019
      grace_period 3s
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

    # BIND-RACE GATE: caddy pins two addresses it does not own, and dies with
    # "bind: cannot assign requested address" if either is missing at ExecStart.
    # Both are assigned asynchronously by something else, so ordering alone
    # cannot settle it — the gate below is what actually guarantees presence.
    #   100.102.255.10   the Caddyfile's `bind` (tailscale0). tailscaled assigns
    #                    it only after it authenticates.
    #   10.228.107.1     the admin endpoint above (incusbr0). Created with the
    #                    bridge when incus starts.
    # Only the first was gated originally, which is exactly how the 2026-10-10
    # reboot went: the tailnet wait passed, the bridge did not yet exist, and
    # caddy exited 1 on the admin listener with every vhost behind it.
    after = [ "tailscaled.service" "incus.service" ];
    wants = [ "tailscaled.service" ];
    serviceConfig.ExecStartPre = pkgs.writeShellScript "wait-for-bind-ips" ''
      for ip in 100.102.255.10 10.228.107.1; do
        ok=
        for _ in $(seq 1 60); do
          if ${pkgs.iproute2}/bin/ip -4 -o addr show | ${pkgs.gnugrep}/bin/grep -qw "$ip"; then
            ok=1
            break
          fi
          sleep 1
        done
        if [ -z "$ok" ]; then
          echo "wait-for-bind-ips: $ip not assigned after 60s" >&2
          exit 1
        fi
      done
    '';

    # And if it still loses a race, keep trying rather than parking in `failed`
    # with the whole estate behind it. The module already gives us
    # Restart=on-failure and RestartSec=5s; what it also gives us is
    # StartLimitBurst=10 inside a 4h window, so ten quick failures park the
    # unit for four hours. Backoff + no give-up, same reasoning as
    # netbird-management in ./netbird.nix.
    serviceConfig.RestartSteps = 5;
    serviceConfig.RestartMaxDelaySec = 60;
    startLimitIntervalSec = 0;
  };

  # Static-site vhosts serve from /var/www/<site> — migrate those trees over
  # and make sure the caddy user can read them.
  # (bases, lageriet, nytta, chess, skole, totalfrihet, themebases, arne, tjue)

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  # HTTP/3
  networking.firewall.allowedUDPPorts = [ 443 ];
}
