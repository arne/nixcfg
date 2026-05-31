{ config, ... }:

###########################################################################
## firsthouse (Phase 6) — host instantiation on oink.
##
## The portal system itself (Go app + sandbox image + the NixOS module that
## defines `services.firsthouse`) lives in its own repo and is pulled in as the
## `firsthouse` flake input (imported in flake.nix). This file is purely the
## oink-specific wiring: enable it, hand it oink's secrets and the Incus socket
## group. See ./firsthouse/DESIGN.md for the picture.
##
## External prerequisites (NOT expressible here — do once in the Tailscale
## admin console / by minting a key):
##   * tailnet B's policy carries the frozen Phase-6 tagOwners + grants:
##       tag:sandbox-provisioner -> autogroup:admin
##       tag:firsthouse          -> autogroup:admin
##       tag:sandbox             -> tag:sandbox-provisioner
##       grant member -> tag:firsthouse  tcp:22   (reach the portal)
##       grant member -> tag:sandbox     tcp:*    (see each other's services)
##   * the OAuth client (tag:sandbox-provisioner) OWNS tag:sandbox, with
##     auth_keys + devices write scope (reused from Phase 5);
##   * a tag:firsthouse auth key is minted and stored at
##     secrets/oink.yaml -> firsthouse/tailnet-authkey (first join only).
###########################################################################

let
  user = config.services.firsthouse.user;
in
{
  services.firsthouse = {
    enable = true;
    hostname = "firsthouse";

    # Incus access: same client package + socket group oink's daemon uses, so
    # the portal can launch / exec / delete sandboxes over the local socket.
    incusGroup = "incus-admin";
    incusPackage = config.virtualisation.incus.clientPackage;

    # The portal's own tailnet-B node identity (tag:firsthouse), first join only.
    authKeyFile = config.sops.secrets."firsthouse/tailnet-authkey".path;
    # Reuses the Phase-5 OAuth client secret to mint tag:sandbox keys for boxes.
    oauthSecretFile = config.sops.secrets."tailscale-sandbox/oauth-client-secret".path;
  };

  # The tag:firsthouse node auth key. Mint manually (or via the OAuth client)
  # and store with `sops secrets/oink.yaml`; must be readable by the service user.
  sops.secrets."firsthouse/tailnet-authkey" = {
    owner = user;
    mode = "0400";
  };

  # The OAuth secret already exists (declared in ./secrets.nix, root-owned for
  # the Phase-5 scripts). The portal runs as an unprivileged user, so it needs
  # read access too — re-own it to the service user (root, via sudo, still reads
  # it for the scripts).
  sops.secrets."tailscale-sandbox/oauth-client-secret".owner = user;
}
