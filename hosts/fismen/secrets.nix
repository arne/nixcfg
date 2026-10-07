{ ... }:

{
  ###########################################################################
  ## Secrets (sops-nix) — INERT until secrets/fismen.yaml exists; flip the
  ## wiring below on once it does (eval fails if the file is missing).
  ##
  ## The host key is PRE-GENERATED (oink:~/fismen-install/etc/ssh/, age
  ## recipient &fismen in ../../.sops.yaml) and injected at install time via
  ## `nixos-anywhere --extra-files ~/fismen-install`, so secrets decrypt on
  ## the very first boot — no post-install key dance.
  ##
  ## Create the file ON OINK (the &arne admin key is the id_ed25519 there):
  ##   cd <repo> && export SOPS_AGE_KEY="$(ssh-to-age -private-key -i ~/.ssh/id_ed25519)"
  ##   sops set secrets/fismen.yaml '["caddy"]["cloudflare-env"]' '"CLOUDFLARE_API_TOKEN=<token>"'
  ##   sops set secrets/fismen.yaml '["nyheter"]["oidc-env"]'     '"OIDC_CLIENT_ID=...\nOIDC_CLIENT_SECRET=..."'
  ## (values: see the live units captured in MIGRATION.md / the old host's
  ##  /etc/caddy/secrets/cloudflare-token)
  ##
  ## The consuming units use tolerant `-/run/secrets/<key>` EnvironmentFile
  ## paths (caddy.nix, services.nix), which is exactly where sops-nix places
  ## these keys — arming the wiring requires no other changes.
  ###########################################################################

  sops.defaultSopsFile = ../../secrets/fismen.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets."caddy/cloudflare-env" = { mode = "0400"; };
  sops.secrets."nyheter/oidc-env"     = { mode = "0400"; };

  # NetBird control plane (./netbird.nix). netbird-management reads these as
  # root through its jq pre-start, but coturn's pre-start runs as the
  # `turnserver` user, so turn-password needs that owner or coturn dies with
  # EACCES before it ever starts. root still reads it regardless of owner.
  #   sops set secrets/fismen.yaml '["netbird"]["datastore-key"]'  '"<32+ random bytes>"'
  #   sops set secrets/fismen.yaml '["netbird"]["turn-password"]'  '"<random>"'
  #   sops set secrets/fismen.yaml '["netbird"]["turn-secret"]'    '"<random>"'
  # datastore-key encrypts the peer store at rest: BACK IT UP. Losing it means
  # re-enrolling every peer, and it must stay identical across restores.
  sops.secrets."netbird/datastore-key"  = { mode = "0400"; };
  sops.secrets."netbird/turn-password"  = { mode = "0400"; owner = "turnserver"; };
  sops.secrets."netbird/turn-secret"    = { mode = "0400"; };

  # The Pocket ID client secret for the `netbird` OIDC client. Management hands
  # it to enrolled peers for the PKCE token exchange; it is NOT the dashboard's
  # public AUTH_CLIENT_SECRET.
  #   sops set secrets/fismen.yaml '["netbird"]["oidc-client-secret"]' '"<secret>"'
  sops.secrets."netbird/oidc-client-secret" = { mode = "0400"; };

  # navidrome/env is gone with navidrome itself (replaced by gonic, which has
  # no equivalent key: it stores credentials in its own DB). The stale value is
  # still encrypted in secrets/fismen.yaml — prune it alongside beszel's below.
  #
  # beszel/agent-env is deliberately NOT declared any more: the agent moved to
  # the shared module (../../modules/services/beszel.nix) and its new hub
  # authenticates by public key, so there is no secret to decrypt. The stale
  # value is still encrypted in secrets/fismen.yaml — prune it when convenient.
}
