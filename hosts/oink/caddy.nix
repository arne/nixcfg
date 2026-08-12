{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## Caddy — public reverse proxy / TLS terminator. Fronts the kokosbananas
  ## project, which runs in its own Incus container (10.100.0.122) and is
  ## exposed to the host by the container's `web` proxy device (host
  ## 0.0.0.0:8080 -> 127.0.0.1:8080 inside the container). Caddy gets an
  ## automatic Let's Encrypt cert per hostname (DNS A records point at this
  ## box's 185.181.63.4) and reverse-proxies cleartext to localhost:8080.
  ## Ports 80/443 are opened in the firewall block in configuration.nix.
  ###########################################################################
  services.caddy = {
    enable = true;
    email = "arnefismen@gmail.com";  # ACME account — Let's Encrypt expiry notices.
    # The global `log { level ERROR }` block is emitted automatically by the
    # NixOS module: services.caddy.logFormat already defaults to "level ERROR".
    virtualHosts."goltenstories.no, kokosbananas.tjue.net" = {
      # The NixOS module already wraps this in `log { ... }`. Override the
      # default access-log path (which is auto-named after the vhost key, comma
      # and all) so both hostnames log to one tidy file.
      logFormat = "output file /var/log/caddy/access-kokosbananas.tjue.net.log";
      extraConfig = ''
        # oauth2-proxy's own endpoints (sign-in, OIDC callback, sign-out).
        handle /oauth2/* {
          reverse_proxy 127.0.0.1:4180 {
            header_up X-Real-IP {remote_host}
          }
        }

        # Public podcast surface — Spotify/Apple fetch feeds, enclosures and
        # artwork unauthenticated on their own schedule (ADR-0001/0015/0017).
        @public path /feed/* /audio/* /images/*
        handle @public {
          reverse_proxy localhost:8080
        }

        # Everything else requires a Pocket ID session
        # (tilgang.goltenstories.no), enforced by oauth2-proxy.
        handle {
          forward_auth 127.0.0.1:4180 {
            uri /oauth2/auth
            header_up X-Real-IP {remote_host}
            copy_headers X-Auth-Request-User X-Auth-Request-Email

            # No session → bounce to the sign-in flow, returning here after.
            @noauth status 401
            handle_response @noauth {
              redir * /oauth2/sign_in?rd={scheme}://{host}{uri} 302
            }
          }
          reverse_proxy localhost:8080
        }
      '';
    };

    # Kokosbananas player — PWA podcast player in the same kokosbananas
    # container (Incus proxy device container:8081 → host 127.0.0.1:8081).
    # Entirely behind Pocket ID auth; it consumes the public feed above
    # server-side, so nothing here needs to be reachable unauthenticated.
    virtualHosts."kokos.goltenstories.no" = {
      logFormat = "output file /var/log/caddy/access-kokos.goltenstories.no.log";
      extraConfig = ''
        handle /oauth2/* {
          reverse_proxy 127.0.0.1:4180 {
            header_up X-Real-IP {remote_host}
          }
        }

        handle {
          forward_auth 127.0.0.1:4180 {
            uri /oauth2/auth
            header_up X-Real-IP {remote_host}
            copy_headers X-Auth-Request-User X-Auth-Request-Email

            @noauth status 401
            handle_response @noauth {
              redir * /oauth2/sign_in?rd={scheme}://{host}{uri} 302
            }
          }
          reverse_proxy localhost:8081
        }
      '';
    };

    # Pocket ID — passkey OIDC provider in the services container (10.100.0.x,
    # Incus proxy device maps container:1411 → host:1411).
    virtualHosts."tilgang.verftet.info" = {
      logFormat = "output file /var/log/caddy/access-tilgang.verftet.info.log";
      extraConfig = ''
        reverse_proxy localhost:1411
      '';
    };

    # Pocket ID #2 — separate instance for the goltenstories org (same
    # services container, proxy device container:1412 → host:1412).
    virtualHosts."tilgang.goltenstories.no" = {
      logFormat = "output file /var/log/caddy/access-tilgang.goltenstories.no.log";
      extraConfig = ''
        reverse_proxy localhost:1412
      '';
    };
  };
}
