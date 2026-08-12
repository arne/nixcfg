{ config, ... }:

{
  ###########################################################################
  ## oauth2-proxy — OIDC client for the goltenstories Pocket ID instance
  ## (tilgang.goltenstories.no). Caddy forward_auths the kokosbananas vhosts
  ## to this (caddy.nix); it runs the code flow against Pocket ID and holds
  ## the session cookie. Client id/secret (minted in the Pocket ID admin UI)
  ## and the cookie secret arrive via the sops env file declared in
  ## secrets.nix — nothing sensitive lives in the store.
  ###########################################################################
  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    oidcIssuerUrl = "https://tilgang.goltenstories.no";
    httpAddress = "http://127.0.0.1:4180";
    reverseProxy = true; # trust X-Forwarded-* from Caddy (also derives the
    # per-host /oauth2/callback redirect URL, so both vhost names work).
    setXauthrequest = true; # X-Auth-Request-User/Email for the app, via
    # forward_auth copy_headers.
    email.domains = [ "*" ]; # who gets in is decided by who has a Pocket ID
    # account on this instance, not by mail domain.
    keyFile = config.sops.secrets."kokosbananas/oauth2-proxy-env".path;
    extraConfig = {
      code-challenge-method = "S256"; # PKCE — supported by Pocket ID.
      # Pocket ID doesn't run an email-verification flow, so id_tokens carry
      # email_verified=false. Accounts are admin-created only, so accept them.
      insecure-oidc-allow-unverified-email = true;
      trusted-proxy-ip = [ "127.0.0.1/32" ]; # only Caddy may set X-Forwarded-*.
      provider-display-name = "tilgang.goltenstories.no";
      # Allowed absolute ?rd= targets after sign-in (both vhost names).
      whitelist-domain = [
        "goltenstories.no"
        "kokos.goltenstories.no"
        "kokosbananas.tjue.net"
      ];
    };
  };
}
