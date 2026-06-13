{ ... }:

{
  ###########################################################################
  ## comin — pull-based GitOps for the server hosts (oink, fismen).
  ##
  ## The daemon polls this repo's main branch (60 s) and deploys the
  ## nixosConfiguration matching the machine's hostname. With branch-protected
  ## main, MERGING A PR IS THE DEPLOY — no SSH fan-out, no local checkouts in
  ## the loop (which is how oink once got rebuilt from a stale clone).
  ##
  ## Risky changes: push to `testing-<hostname>` instead — comin applies those
  ## with `switch-to-configuration test` (NOT made the boot default), so a bad
  ## config is one reboot away from the last good generation. Merge to main
  ## when satisfied.
  ##
  ## Limits to keep in mind:
  ##  * Pull-based: a config that breaks the machine's networking can't fetch
  ##    its own fix. Use the testing branch for anything touching network,
  ##    firewall, tailscale, or incus bridges.
  ##  * Builds happen ON the machine; first deploy after a nixpkgs bump does
  ##    real work.
  ##
  ## TODO (security): enable services.comin.gpgPublicKeyPaths once commit
  ## signing is set up. The repo is public and commits are currently
  ## unsigned, so until then anyone controlling the GitHub repo can deploy to
  ## these machines — the same trust we already place in it, but signature
  ## verification would pin trust to the signing key instead.
  ###########################################################################
  services.comin = {
    enable = true;
    remotes = [
      {
        name = "github";
        url = "https://github.com/arne/nixcfg.git";
        # Defaults: branches.main.name = "main" (operation: switch),
        # branches.testing.name = "testing-<hostname>" (operation: test),
        # poller.period = 60.
      }
    ];
  };
}
