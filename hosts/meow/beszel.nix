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
  ## /var/lib/beszel-hub -> /var/lib/private/beszel-hub, since the upstream
  ## unit runs under DynamicUser. It is NOT in hosts/meow/backup.nix: this is
  ## regenerable monitoring history, not data. If that changes, back up the
  ## whole directory — the DB is sqlite and the key must survive with it, or
  ## every agent's KEY has to be re-issued.
  ##
  ## MANUAL STEPS:
  ##   1. Add the UniFi DNS record: status.azf.no -> 10.69.68.3
  ##   2. First visit to https://status.azf.no creates the admin account —
  ##      do this immediately after the deploy; until an account exists the
  ##      signup form is open to anyone who can resolve the name.
  ##   3. Grab the hub's public key and turn the agents on — the full
  ##      procedure is in modules/services/beszel.nix.
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
    };
  };

  # Caddy vhost for the hub lives in ./caddy.nix, next to ha.azf.no, so all of
  # meow's TLS surface is in one file.
}
