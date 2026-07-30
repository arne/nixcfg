{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## Beszel hub — the fleet's monitoring dashboard, at https://status.azf.no.
  ##
  ## THIS REPLACES the old hub, which was an Incus instance on fismen
  ## (10.228.107.118, fronted by monitor.fismen.no in hosts/fismen/Caddyfile)
  ## and therefore lived outside NixOS entirely. That container is left running
  ## and untouched by this change — it just loses its only agent, since
  ## fismen's now reports here instead (see hosts/fismen/services.nix).
  ## Retire it when this hub has proven itself: delete the container, then the
  ## monitor.fismen.no vhost. History does NOT carry over; if the graphs
  ## matter, copy the container's beszel data dir into /var/lib/beszel-hub
  ## while this unit is stopped, before first start.
  ##
  ## WHY MEOW: it is the always-on box at home, it already terminates TLS for
  ## azf.no (hosts/meow/caddy.nix), and it is the tailnet's subnet router, so
  ## it has a route to every agent. Putting the hub on fismen or oink would
  ## mean a public-facing dashboard for a purely private thing.
  ##
  ## The hub binds 127.0.0.1 only — Caddy is the sole way in, so there is no
  ## new firewall port on any interface, not even tailscale0. Reachability of
  ## status.azf.no follows exactly the same rules as ha.azf.no: no public A
  ## record, a UniFi DNS override to 10.69.68.3, so it resolves on the LAN and
  ## through the subnet router from the tailnet, and nowhere else.
  ##
  ## State (the PocketBase DB, the hub's SSH key, all history) lives in
  ## /var/lib/beszel-hub/beszel_data -> /var/lib/private/beszel-hub/beszel_data,
  ## since the upstream unit runs under DynamicUser and the hub puts its
  ## PocketBase data one level down. It is NOT in hosts/meow/backup.nix: this is
  ## regenerable monitoring history, not data. If that changes, back up the
  ## whole directory — the DB is sqlite and the key must survive with it, or
  ## every agent's KEY has to be re-issued.
  ##
  ## MANUAL STEPS (the hub itself is deployed and running):
  ##   1. Point the azf.no zone at meow (see hosts/meow/caddy.nix).
  ##   2. First visit to https://status.azf.no/_/ creates the PocketBase
  ##      SUPERUSER — do this immediately; until it exists that setup page is
  ##      open to anyone who can resolve the name. This account is the admin /
  ##      break-glass login and is NOT affected by the OIDC switch below.
  ##   3. Wire up Pocket ID as the app login — see the OIDC PROVIDER block
  ##      below.
  ##   4. Add one system per host, all with port 45876 and MagicDNS names so
  ##      nothing breaks when a tailnet IP changes:
  ##
  ##        meow      127.0.0.1   (the hub's own box — no need to go via the tailnet)
  ##        fox       fox
  ##        fismen    fismen
  ##        oink      oink
  ##        roar      roar
  ##
  ##      The system list lives in the hub's DB, not here: beszel has no
  ##      declarative inventory, so this step cannot be expressed in Nix.
  ###########################################################################
  services.beszel.hub = {
    enable = true;
    host = "127.0.0.1";
    port = 8090;

    environment = {
      # Used for the links in alert emails/webhooks — without it they point at
      # localhost and are useless from a phone.
      APP_URL = "https://status.azf.no";

      # AUTH — the ONLY way into the app is Pocket ID at auth.fismen.no (OIDC).
      #
      # DISABLE_PASSWORD_AUTH kills email+password login on the `users`
      # collection (beszel internal/hub/collections.go sets PasswordAuth.Enabled
      # = false from this). It must be set HERE, not toggled in the PocketBase
      # UI: beszel re-applies the env value on every start and would clobber a
      # UI change. NOTE this does NOT touch the PocketBase SUPERUSER login at
      # https://status.azf.no/_/ — that stays password-based on purpose, as the
      # break-glass admin door and the only place the OIDC provider is
      # configured. Guard that account (long password / the built-in OTP MFA).
      DISABLE_PASSWORD_AUTH = "true";
      # Provision a `users` record on first successful OIDC login. Without it,
      # beszel refuses to create accounts and every user must be pre-made by
      # hand with a matching email — so with password auth off AND this off, a
      # brand-new hub has no non-superuser way in at all. Acceptable to leave
      # open here because auth.fismen.no is our own single-tenant IdP: whoever
      # it lets authenticate is already us.
      USER_CREATION = "true";
    };
  };

  ###########################################################################
  ## OIDC PROVIDER — the one part that cannot be declared. The client
  ## id/secret and issuer live in beszel's PocketBase DB (data.db, encrypted
  ## with the app key), not in any env var, so this is a one-time UI step:
  ##
  ##   1. In Pocket ID (https://auth.fismen.no) register a new OIDC client:
  ##        name          Beszel
  ##        callback URL  https://status.azf.no/api/oauth2-redirect
  ##      Note the generated Client ID and Client Secret.
  ##   2. Log into https://status.azf.no/_/ as the PocketBase superuser and, at
  ##      /_/#/settings, turn OFF "Hide collection create and edit controls".
  ##   3. Edit the `users` collection → Options tab → enable OAuth2 → add an
  ##      OIDC provider pointed at auth.fismen.no's discovery document
  ##      (https://auth.fismen.no/.well-known/openid-configuration) with the
  ##      client id/secret from step 1. Turn the controls toggle back on.
  ##   4. Sign out and confirm the login page offers ONLY the Pocket ID button
  ##      (DISABLE_PASSWORD_AUTH above removes the email/password form).
  ##
  ## The client secret ends up only in data.db, so it is covered by whatever
  ## backs that up — there is nothing to add to sops.
  ###########################################################################

  # Caddy vhost for the hub lives in ./caddy.nix, next to ha.azf.no, so all of
  # meow's TLS surface is in one file.
}
