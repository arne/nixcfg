{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## Caddy — TLS termination for the azf.no zone, which now points here rather
  ## than at fismen:
  ##   ha.azf.no      -> Home Assistant       (modules/services/home-assistant.nix)
  ##   status.azf.no  -> Beszel hub           (./beszel.nix)
  ##   fleet.azf.no   -> fleet status page    (./fleet-web.nix)
  ##   ai.azf.no      -> open-webui on fox    (tailnet-only; moved off fismen)
  ##
  ## WHY A PUBLIC NAME FOR A PRIVATE SERVICE: `.internal` can never have a
  ## publicly-trusted certificate (that is the point of a reserved TLS-less
  ## TLD), so a real name is the only way to a valid padlock without shipping
  ## a private root CA to every phone and tablet in the house.
  ##
  ## NOTHING IS EXPOSED PUBLICLY, but not for the reason an earlier version of
  ## this comment claimed. These names DO have public A records in Cloudflare —
  ## they just resolve to addresses nobody outside can route to: 10.69.68.3
  ## (meow on the LAN) or a 100.64/10 tailnet address. Publishing an
  ## unroutable address is what makes the name work identically on the LAN and
  ## the tailnet without a private root CA, and it is also why a UniFi DNS
  ## override is optional rather than load-bearing.
  ##
  ## The certificate is obtained over DNS-01, which proves domain control by
  ## writing a TXT record — it never requires an inbound connection, so it
  ## works fine for a host with no public listener.
  ##
  ## The caddy build and the (cf) DNS-01 idiom are lifted from
  ## hosts/fismen/caddy.nix — keep the plugin version in sync with that host.
  ##
  ## MANUAL STEPS:
  ##   1. Mint a Cloudflare token scoped to Zone:DNS:Edit on azf.no ONLY (do
  ##      not reuse fismen's — meow is not a recipient of secrets/fismen.yaml
  ##      and a per-host token limits the blast radius).
  ##   2. Store it (from the mac, or from meow with its host key as the age
  ##      identity):
  ##        sops set secrets/meow.yaml '["caddy"]["cloudflare-env"]' \
  ##          '"CLOUDFLARE_API_TOKEN=<token>"'
  ##   3. Point the azf.no zone at meow in Cloudflare: the `*.azf.no` wildcard
  ##      (plus the apex and www, which are vestigial — fismen serves no vhost
  ##      for either) currently reads 100.102.255.10, fismen's tailnet IP.
  ##      10.69.68.3 is the right target: ha.azf.no already uses it, and it is
  ##      the superset — reachable from the LAN directly and from the tailnet
  ##      through meow's own subnet route. ai.azf.no stays tailnet-only by its
  ##      remote_ip guard below, not by DNS.
  ###########################################################################
  services.caddy = {
    enable = true;

    # ACME account email — Let's Encrypt expiry notices.
    email = "arnefismen@gmail.com";

    # Same override as fismen: withPlugins rebuilds caddy with the DEFAULT Go
    # builder (1.25) on 25.11, but caddy's go.mod needs >= 1.26.3.
    #
    # PLUGIN v0.2.4, NOT fismen's v0.2.3 — deliberate divergence. Cloudflare
    # now issues account/user tokens prefixed cfat_/cfut_, and v0.2.3's
    # validation rejects them outright ("API token appears invalid"), so it
    # cannot be used with any token minted today. v0.2.4 is exactly one
    # commit ahead: caddy-dns/cloudflare#123, which accepts the new shapes.
    # fismen still works only because its token predates the change; it will
    # hit this the moment that token is rotated.
    package =
      (pkgs.caddy.override { buildGoModule = pkgs.buildGo126Module; }).withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
        hash = "sha256-Q0lgI8MY90u/5R/xXBVPQWCZBN7dUZ0kcuDxD0xd0fo=";
      };

    virtualHosts."ha.azf.no".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy 127.0.0.1:8123
    '';

    # Beszel hub. It binds 127.0.0.1:8090, so this vhost is the only way in.
    virtualHosts."status.azf.no".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy 127.0.0.1:8090
    '';

    # fleet.azf.no — the `fleet` status page. A static file rendered hourly by
    # the fleet-web timer (./fleet-web.nix) into /var/lib/fleet-web.
    virtualHosts."fleet.azf.no".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      root * /var/lib/fleet-web
      file_server
    '';

    # ai.azf.no — open-webui on fox. MOVED HERE FROM fismen (it was the only
    # azf.no vhost left there) so that the whole azf.no zone can point at meow.
    #
    # TAILNET-ONLY, same as it was on fismen: the remote_ip guard means only
    # clients whose source address is inside the tailnet CGNAT range get
    # through, so a plain LAN client is refused even though the name now
    # resolves to meow. A tailnet client coming in through meow's subnet router
    # keeps its 100.x source address, so it still passes.
    #
    # fismen's `bind 100.102.255.10` is deliberately NOT carried over. Its only
    # job was keeping this listener off fismen's PUBLIC interface; meow has no
    # public address at all, so pinning meow's tailnet IP here would add a
    # cold-boot race (see the ExecStartPre gate in hosts/fismen/caddy.nix) to
    # protect against nothing.
    virtualHosts."ai.azf.no".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      @notTailnet not remote_ip 100.64.0.0/10 fd7a:115c:a1e0::/48
      abort @notTailnet
      reverse_proxy fox.little-lenok.ts.net:8080
    '';
  };

  # CLOUDFLARE_API_TOKEN for DNS-01; one line: CLOUDFLARE_API_TOKEN=...
  # The `-` prefix makes a missing file non-fatal, so a fresh boot before sops
  # bring-up doesn't leave caddy in a restart loop — it just can't issue yet.
  systemd.services.caddy.serviceConfig.EnvironmentFile =
    "-/run/secrets/caddy/cloudflare-env";

  # 80 is only here for the HTTP->HTTPS redirect; DNS-01 does not use it.
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 443 ]; # HTTP/3
}
