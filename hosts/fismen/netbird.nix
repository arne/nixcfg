{ config, lib, ... }:

let
  # The `netbird` OIDC client registered in Pocket ID. Not a secret: it travels
  # in every authorization URL and is baked into the public dashboard build.
  # NetBird validates the JWT `aud` claim against it, so the audience fields
  # below must carry the client ID, not the literal string "netbird".
  clientId = "dd7245f0-4e66-4197-98bd-641ce2ba25bd";
in
{
  ###########################################################################
  ## NetBird control plane (Phase 1 of the Tailscale -> NetBird migration).
  ##
  ## fismen hosts it because a control plane must be reachable from wherever a
  ## peer happens to be: this box has a stable public v4 AND v6 address, no NAT
  ## in front of it, and spare capacity. meow was considered and rejected — its
  ## names resolve to unroutable addresses by design (see hosts/meow/caddy.nix)
  ## and a v6-only standby fails exactly when it is needed, on a v4-only hotel
  ## network. There is deliberately NO second control plane: active-active
  ## Management/Signal is a NetBird Enterprise feature (shared PostgreSQL +
  ## Redis + NATS), and an outage only blocks new logins, enrolments and policy
  ## changes — established WireGuard tunnels keep forwarding throughout.
  ##
  ## Two domains, two different jobs — do not conflate them. They sit in
  ## different zones deliberately: azf.no stays internal-only, and the one name
  ## that must face the public lives in fismen.no, which already does.
  ##   nb.fismen.no  PUBLIC. Dashboard + Management + Signal + TURN. Every peer
  ##                 dials this name. It already resolves: the `*.fismen.no`
  ##                 wildcard points at 135.181.130.98 (this host) and the zone
  ##                 is NOT Cloudflare-proxied, which matters because the proxy
  ##                 breaks gRPC-over-h2c and cannot carry coturn's UDP at all.
  ##                 The zone has no AAAA anywhere, so an explicit one for this
  ##                 name is the only DNS work worth doing (see below).
  ##   nb.azf.no     OVERLAY ONLY. The peer DNS suffix — NetBird's MagicDNS
  ##                 equivalent, replacing *.little-lenok.ts.net. A dedicated
  ##                 label on purpose: pointing dnsDomain at azf.no itself would
  ##                 make every peer's resolver claim the whole zone and shadow
  ##                 the real ha/status/fleet/ai/llm.azf.no records on meow.
  ##
  ## Identity is the Pocket ID already running at auth.fismen.no. It advertises
  ## the device_code grant and S256 PKCE, which is all NetBird needs, so there
  ## is no Zitadel/Keycloak here. Both flows are configured: device code for
  ## headless `netbird up`, PKCE for the dashboard and desktop clients.
  ##
  ## MANUAL PREREQUISITES:
  ##   1. DONE: the `netbird` OIDC client is registered in Pocket ID as
  ##      dd7245f0-4e66-4197-98bd-641ce2ba25bd (see `clientId` below), with
  ##      callbacks https://nb.fismen.no/auth, /silent-auth and
  ##      http://localhost:53000.
  ##   2. DONE: the secrets below are in secrets/fismen.yaml:
  ##        netbird/datastore-key   32+ random bytes. NOT optional — the module
  ##                                default is the literal "very-insecure-key"
  ##                                and it encrypts the peer store at rest.
  ##                                Back this up: without it the store is
  ##                                unreadable, so losing it means re-enrolling
  ##                                every peer.
  ##        netbird/turn-password   random; coturn's shared password.
##        netbird/turn-secret     random; shared secret for time-limited TURN
##                                credentials (module default is a placeholder).
##        netbird/oidc-client-secret  the Pocket ID client secret.
##   3. OPTIONAL, recommended: an explicit AAAA 2a01:4f9:4b:2141::2 for
##      nb.fismen.no. No DNS change is needed to get started — the
##      `*.fismen.no` wildcard already answers with this host's v4 — but the
##      whole zone is v4-only today, so without it a peer on a v6-only
##      network cannot reach the control plane. Keep it DNS-only (grey cloud).
  ###########################################################################

  services.netbird.server = {
    enable = true;
    domain = "nb.fismen.no";

    # Caddy already owns :80/:443 on this host with ~45 vhosts (./caddy.nix),
    # so the module's bundled nginx stays off and ./Caddyfile fronts the stack.
    enableNginx = false;

    management = {
      # Internal listeners; Caddy reverse-proxies to them over loopback.
      port = 8011;

      oidcConfigEndpoint = "https://auth.fismen.no/.well-known/openid-configuration";

      # The suffix handed to peers. `ssh fismen` keeps working because the
      # client pushes this as a DNS search domain, the same trick MagicDNS
      # plays with little-lenok.ts.net today.
      dnsDomain = "nb.azf.no";
      singleAccountModeDomain = "nb.azf.no";

      settings = {
        # Peer store encryption. The module's default is a placeholder.
        DataStoreEncryptionKey = {
          _secret = config.sops.secrets."netbird/datastore-key".path;
        };

        HttpConfig = {
          # Issuer and JWKS are discovered from oidcConfigEndpoint above; the
          # audience has to be asserted here.
          AuthAudience = clientId;
        };

        # Headless login (`netbird up` over SSH, no browser on the box).
        DeviceAuthorizationFlow = {
          Provider = "hosted";
          ProviderConfig = {
            Audience = clientId;
            ClientID = clientId;
            Domain = "auth.fismen.no";
            TokenEndpoint = "https://auth.fismen.no/api/oidc/token";
            DeviceAuthEndpoint = "https://auth.fismen.no/api/oidc/device/authorize";
            Scope = "openid profile email";
            UseIDToken = true;
          };
        };

        # Browser login (dashboard, desktop + mobile clients).
        PKCEAuthorizationFlow.ProviderConfig = {
          Audience = clientId;
          ClientID = clientId;

          # Pocket ID issued this client a secret, so the token exchange is
          # confidential and the secret has to be present. It is handed to
          # enrolled peers by management over TLS — NOT the same thing as the
          # dashboard's AUTH_CLIENT_SECRET, which is baked into public static
          # JS. If the dashboard login ever needs a secret, mark the client
          # PUBLIC in Pocket ID instead of pasting it there.
          ClientSecret = {
            _secret = config.sops.secrets."netbird/oidc-client-secret".path;
          };

          AuthorizationEndpoint = "https://auth.fismen.no/authorize";
          TokenEndpoint = "https://auth.fismen.no/api/oidc/token";
          Scope = "openid profile email";
          RedirectURLs = [ "http://localhost:53000" ];
          UseIDToken = true;
        };

        # Management sits behind Caddy on loopback, so trust the proxy for
        # client-IP attribution instead of the module's 0.0.0.0/0 default.
        ReverseProxy = {
          TrustedHTTPProxies = [ "127.0.0.1" "::1" ];
          TrustedHTTPProxiesCount = 1;
        };

        # Plain UDP TURN on 3478. The stack default builds this against
        # coturn's TLS port, which we are not terminating (Caddy holds the
        # cert); a turns:// listener would need its own copy of it.
        TURNConfig = {
          Turns = [
            {
              Proto = "udp";
              URI = "turn:nb.fismen.no:3478";
              Username = "netbird";
              Password = {
                _secret = config.sops.secrets."netbird/turn-password".path;
              };
            }
          ];

          # Shared secret for time-limited TURN credentials. The module default
          # is the literal "not-secure-secret" and would land world-readable in
          # the Nix store, which it warns about at eval time.
          Secret = {
            _secret = config.sops.secrets."netbird/turn-secret".path;
          };
        };
      };
    };

    signal.port = 10000;

    dashboard.settings = {
      AUTH_AUTHORITY = "https://auth.fismen.no";
      AUTH_AUDIENCE = clientId;
      AUTH_CLIENT_ID = clientId;
      AUTH_SUPPORTED_SCOPES = "openid profile email groups";
      AUTH_REDIRECT_URI = "https://nb.fismen.no/auth";
      AUTH_SILENT_REDIRECT_URI = "https://nb.fismen.no/silent-auth";
      NETBIRD_TOKEN_SOURCE = "idToken";
      USE_AUTH0 = false;
    };

    coturn = {
      enable = true;
      passwordFile = config.sops.secrets."netbird/turn-password".path;

      # No TLS listener (see TURNConfig.Turns above), so coturn needs no cert
      # of its own. The module opens 3478/5349 and the relay UDP range in the
      # firewall by itself — ./configuration.nix does not repeat them.
      useAcmeCertificates = false;
    };
  };

  # The dashboard is a static build; ./Caddyfile serves it from this path and
  # proxies the API/gRPC routes past it. Exported so the Caddyfile and the
  # package stay in lockstep across rebuilds.
  environment.etc."netbird-dashboard".source =
    config.services.netbird.server.dashboard.finalDrv;
}
