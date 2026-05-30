{ lib, ... }:

{
  ###########################################################################
  ## Tailscale — system service, always on. Shared across every host (imported
  ## via modules/base.nix). "client" routing features enable the forwarding
  ## sysctls needed to accept subnet routes / use an exit node; it's an
  ## mkDefault so a host can bump it to "server"/"both" (e.g. an exit node).
  ##
  ## Auth is manual & one-time per host: after the first rebuild, SSH in and run
  ##   sudo tailscale up
  ## State persists in /var/lib/tailscale, so it survives subsequent rebuilds.
  ## (No authKeyFile here — that needs a committed secret, i.e. a secrets
  ## manager we don't have yet.)
  ###########################################################################
  services.tailscale = {
    enable = true;
    useRoutingFeatures = lib.mkDefault "client";
  };
}
