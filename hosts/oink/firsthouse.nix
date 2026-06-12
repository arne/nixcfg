{ config, ... }:

###########################################################################
## firsthouse (Phase 6) — host instantiation on oink.
##
## The portal system (Go app + sandbox image + the NixOS module defining
## `services.firsthouse`) lives in its own repo, pulled in as the `firsthouse`
## flake input. This file is purely oink-specific wiring: enable it, point it at
## oink's secrets + Incus socket group. The module owns the rest — it imports
## its own sandbox image and ensures the `client-sandbox` profile on activation
## (a oneshot before the portal starts), so no manual `incus image import` /
## `sandbox-setup` is needed. Its network/pool defaults (incusbr0 / default)
## already match oink, so nothing to override.
##
## External prerequisites (NOT expressible here — Tailscale admin console):
##   * tailnet B's frozen Phase-6 policy (see ./incus/tailnet-b-acl.phase6.hujson);
##   * the OAuth client (tag:sandbox-provisioner) OWNS tag:sandbox;
##   * a tag:firsthouse auth key minted into secrets/oink.yaml (first join only).
###########################################################################

{
  services.firsthouse = {
    enable = true;
    hostname = "firsthouse";

    # Incus access: same client + socket group oink's daemon uses, so the portal
    # (and the image/profile setup oneshot) can drive the local socket.
    incusGroup = "incus-admin";
    incusPackage = config.virtualisation.incus.clientPackage;

    # Secret references (values live encrypted in secrets/oink.yaml). The unit
    # reads them as root via systemd LoadCredential, so they stay root-owned —
    # no owner override needed here.
    authKeyFile = config.sops.secrets."firsthouse/tailnet-authkey".path;
    oauthSecretFile = config.sops.secrets."tailscale-sandbox/oauth-client-secret".path;
  };

  # The tag:firsthouse node auth key. Mint manually (or via the OAuth client) and
  # store with `sops secrets/oink.yaml`; root-owned is fine (LoadCredential).
  sops.secrets."firsthouse/tailnet-authkey".mode = "0400";
}
