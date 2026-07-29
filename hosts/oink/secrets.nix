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

  # Environment files for the two oauth2-proxy instances that gate
  # goltenstories.no and kokosbananas.tjue.net behind Pocket ID. Each file
  # contains two lines: OAUTH2_PROXY_CLIENT_SECRET (from Pocket ID after
  # OIDC client registration) and OAUTH2_PROXY_COOKIE_SECRET (random 32-byte
  # base64, pre-generated in the repo — rotate with `sops secrets/oink.yaml`).
  # Owner must be "oauth2-proxy" so the service unit can read the file.
  sops.secrets."goltenstories/oauth2-proxy-env" = {
    mode = "0400";
    owner = "oauth2-proxy";
  };
  sops.secrets."goltenstories/oauth2-proxy-tjue-env" = {
    mode = "0400";
    owner = "oauth2-proxy";
  };
}
