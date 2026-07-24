{ ... }:

{
  ###########################################################################
  ## Secrets (sops-nix). Encrypted material lives in ../../secrets/meow.yaml
  ## and is decrypted at activation into /run/secrets using meow's SSH host
  ## key (age). Recipients + encryption policy live in ../../.sops.yaml.
  ##
  ## NOTE: the admin identity that can EDIT these files is arne's key on the
  ## mac (age1jpzmmw4…). meow's own user key derives to a different age
  ## recipient, so `sops secrets/meow.yaml` will not decrypt from this host —
  ## author secrets from the mac:
  ##   SOPS_AGE_KEY="$(ssh-to-age -private-key -i ~/.ssh/id_ed25519)" sops secrets/meow.yaml
  ##   sops updatekeys secrets/meow.yaml     # after editing .sops.yaml recipients
  ###########################################################################
  sops.defaultSopsFile = ../../secrets/meow.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # restic repository password. Read by the backup unit (runs as root), so
  # root-only is right.
  sops.secrets."restic/password" = {
    mode = "0400";
  };

  # Cloudflare token for Caddy's DNS-01 challenge on ha.azf.no. Scoped to
  # Zone:DNS:Edit on azf.no only — NOT the same token as fismen's. Read by
  # the caddy unit via EnvironmentFile (see hosts/meow/caddy.nix), which
  # systemd reads as root before dropping privileges, so 0400 root is fine.
  sops.secrets."caddy/cloudflare-env" = {
    mode = "0400";
  };
}
