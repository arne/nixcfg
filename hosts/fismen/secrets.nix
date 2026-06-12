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
  ##   sops set secrets/fismen.yaml '["beszel"]["agent-env"]'     '"KEY=ssh-ed25519 ...\nTOKEN=..."'
  ## (values: see the live units captured in MIGRATION.md / the old host's
  ##  /etc/caddy/secrets/cloudflare-token)
  ##
  ## The consuming units use tolerant `-/run/secrets/<key>` EnvironmentFile
  ## paths (caddy.nix, services.nix), which is exactly where sops-nix places
  ## these keys — arming the wiring requires no other changes.
  ###########################################################################

  # TODO: uncomment once secrets/fismen.yaml exists (see above).
  # sops.defaultSopsFile = ../../secrets/fismen.yaml;
  # sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  #
  # sops.secrets."caddy/cloudflare-env" = { mode = "0400"; };
  # sops.secrets."nyheter/oidc-env"     = { mode = "0400"; };
  # sops.secrets."beszel/agent-env"     = { mode = "0400"; };
}
