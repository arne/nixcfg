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

  # OAuth client secret for the SEPARATE sandbox tailnet (tailnet B). The
  # provisioner (hosts/oink/incus/new-client.sh) reads it to mint a fresh,
  # single-use, tag:client-sandbox auth key per container via the Tailscale
  # API. It is NOT used by oink's own personal-tailnet tailscaled. Edit with
  # `sops secrets/oink.yaml`.
  sops.secrets."tailscale-sandbox/oauth-client-secret" = {
    mode = "0400";
  };

  # Env file for oauth2-proxy (hosts/oink/oauth2-proxy.nix): OIDC client
  # id/secret from the goltenstories Pocket ID instance + the session cookie
  # secret. Read by systemd (root) as EnvironmentFile, so root:root 0400.
  sops.secrets."kokosbananas/oauth2-proxy-env" = {
    mode = "0400";
    restartUnits = [ "oauth2-proxy.service" ];
  };
}
