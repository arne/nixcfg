{ ... }:

{
  ###########################################################################
  ## Secrets (sops-nix). Encrypted material lives in ../../secrets/*.yaml and
  ## is decrypted at activation into /run/secrets using oink's SSH host key
  ## (age). Recipients + encryption policy live in ../../.sops.yaml.
  ##
  ## Author / rotate (needs an admin age identity — e.g. arne's ~/.ssh/id_ed25519):
  ##   SOPS_AGE_KEY="$(ssh-to-age -private-key -i ~/.ssh/id_ed25519)" sops secrets/oink.yaml
  ##   sops updatekeys secrets/oink.yaml      # after editing .sops.yaml recipients
  ###########################################################################
  sops.defaultSopsFile = ../../secrets/oink.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Auth material for the SEPARATE sandbox tailnet (tailnet B). Consumed by the
  # per-client provisioning flow (Phase 4) to join client containers to
  # tailnet B — it is NOT used by oink's own personal-tailnet tailscaled.
  # Currently a placeholder; replace with a real tag-scoped pre-auth key or
  # OAuth client secret via `sops secrets/oink.yaml` once tailnet B exists.
  sops.secrets."tailscale-sandbox/authkey" = {
    mode = "0400";
  };
}
