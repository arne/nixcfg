{ ... }:

{
  ###########################################################################
  ## NetBird client — joins the self-hosted overlay (Phase 2 of the Tailscale
  ## -> NetBird migration). Imported per-host, NOT from modules/base.nix: the
  ## fleet moves one box at a time, and Tailscale stays enabled fleet-wide
  ## until the migration actually completes.
  ##
  ## `enable = true` is the module's backward-compatible shorthand for a
  ## single client named "netbird": interface wt0, UDP 51820, running as root
  ## rather than hardened. Root is deliberate — it keeps the CLI plainly
  ## `netbird` and the unit plainly `netbird.service` instead of renaming both
  ## to `netbird-<name>`, as a hardened `clients.<name>` would.
  ##
  ## Pointing at the self-hosted control plane is declarative: ManagementURL
  ## and AdminURL are real config.json fields, and the module merges whatever
  ## is set here into /var/lib/netbird/config.json on every start via
  ## /etc/netbird/config.d/50-nixos.json. No wrapper around
  ## `netbird up -m ...` is needed.
  ##
  ## Both are Go `url.URL` STRUCTS, not strings — a string makes the daemon
  ## exit at startup with "cannot unmarshal string into Go struct field
  ## Config.AdminURL of type url.URL" and crash-loop. Scheme and Host are the
  ## only fields worth writing; the daemon fills in the other nine itself and
  ## persists them back, so this is its own on-disk representation. The ":443"
  ## is likewise not cosmetic — it is the shape netbird writes (cf. its own
  ## default, https://api.netbird.io:443).
  ##
  ## Auth is manual & one-time per host, exactly like Tailscale next door:
  ##   sudo netbird up
  ## prints a URL + code to complete in a browser against auth.fismen.no
  ## (the control plane's DeviceAuthorizationFlow, see hosts/fismen/netbird.nix).
  ## The result persists in /var/lib/netbird/state.json, so reboots and
  ## rebuilds do not repeat it.
  ##
  ## A setup key via `login.enable` is deliberately NOT used, and would not
  ## work on client 0.60.2 anyway: the upstream login unit passes the key as
  ## NB_SETUP_KEY_FILE, and that variable does not exist in this version,
  ## which reads a key only from `--setup-key`/`--setup-key-file`.
  ##
  ## Running both overlays at once is safe despite both allocating out of
  ## 100.64.0.0/10. NetBird hands out a /16 (fismen got 100.117.77.242/16) and
  ## tailscaled installs one /32 per peer in routing table 52, consulted at
  ## rule priority 5270 ahead of `main` — so tailnet peers keep winning on
  ## their own addresses. DNS splits per-link in resolved: little-lenok.ts.net
  ## on tailscale0, nb.azf.no on wt0.
  ###########################################################################
  services.netbird = {
    enable = true;

    clients.default.config =
      let
        controlPlane = {
          Scheme = "https";
          Host = "nb.fismen.no:443";
        };
      in
      {
        ManagementURL = controlPlane;
        AdminURL = controlPlane;
      };
  };
}
