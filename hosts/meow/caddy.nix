{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## Caddy — TLS termination for Home Assistant at https://ha.azf.no.
  ##
  ## WHY A PUBLIC NAME FOR A PRIVATE SERVICE: `.internal` can never have a
  ## publicly-trusted certificate (that is the point of a reserved TLS-less
  ## TLD), so a real name is the only way to a valid padlock without shipping
  ## a private root CA to every phone and tablet in the house.
  ##
  ## NOTHING IS EXPOSED PUBLICLY. The certificate is obtained over DNS-01,
  ## which proves domain control by writing a TXT record — it never requires
  ## an inbound connection. `ha.azf.no` deliberately has NO public A record;
  ## it resolves only via the UniFi DNS override to 10.69.68.3, so the name
  ## works on the LAN and (through the subnet router) the tailnet, and
  ## resolves to nothing at all from the outside.
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
  ##   3. Add the UniFi DNS record: ha.azf.no -> 10.69.68.3
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
