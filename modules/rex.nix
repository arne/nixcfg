{ inputs, ... }:

{
  ###########################################################################
  ## Rex (superlogical.com/rex) — terminal multiplexer, pre-release. Imported
  ## per-host, not from modules/base.nix: it is a server-side thing for the
  ## boxes we ssh into, and air/fox have no use for a login server.
  ##
  ## Login server rather than `services.rex.enable`: one root process that
  ## names each caller (local uid, or Tailscale identity via the host's
  ## tailscaled) and runs a Rex server per account, as that account. The
  ## shared-server mode would run everything as a `rex` user instead, which is
  ## the wrong owner for shells on these machines. The module writes the
  ## accounts below to /etc/rex/accounts.jsonc; it does not create the users,
  ## and `arne` already exists everywhere this is imported.
  ##
  ## Tailscale Serve exposes it on the tailnet at https://<host>.little-lenok.ts.net:7297.
  ## 7297, not 443, because Serve grabs its port for ALL tailnet traffic to
  ## the host, and fismen and meow already run caddy on 443. The Rex CLI
  ## tries both 443 and 7297, so clients still only need the hostname.
  ##
  ## Pre-release token: until Rex's first release the flake tarball sits
  ## behind HTTP basic auth (user "rex", password = the token). Nix reads it
  ## from /etc/nix/netrc, which is written BY HAND on each host — root:wheel
  ## 0640, so `nix flake update rex` works as arne too — and deliberately not
  ## in sops: evaluation fetches the input before activation could ever write
  ## a secret, so a sops-managed netrc would chicken-and-egg on every new host.
  ## Any machine that evaluates this flake (not just builds it) needs that
  ## file. Drop it, and this comment, once Rex ships publicly.
  ###########################################################################
  imports = [ inputs.rex.nixosModules.default ];

  services.rex.loginServer = {
    enable = true;
    # peer:1000 is arne on the local socket (uid 1000 on every host — checked
    # on fismen, meow, roar). tailscale:arne@github is arne from any of
    # arne's tailnet devices.
    accounts.arne.principals = [ "peer:1000" "tailscale:arne@github" ];
    defaults."tailscale:arne@github" = "arne";
    tailscaleServe.enable = true;
  };
}
