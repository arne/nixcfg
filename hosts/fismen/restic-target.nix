{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## restic repository target — fismen stores other hosts' backups.
  ##
  ## Plain SFTP into a dedicated account rather than rest-server: no extra
  ## daemon, no port, no cert, and the mirrored ZFS rpool is already the
  ## durable thing we want. Reachable over the tailnet only — sshd is not
  ## exposed beyond it.
  ##
  ## The client (meow) authenticates with its SSH HOST key, not a user key,
  ## so there is no private key material in sops for this. See
  ## hosts/meow/backup.nix.
  ##
  ## LIMITATION worth knowing: this account can delete its own snapshots, so
  ## it is a backup, NOT ransomware protection — a compromised meow could
  ## `restic forget --prune` its history. Fixing that properly means
  ## rest-server in --append-only mode. Given the threat model here (disk
  ## failure, not attacker), that trade is deliberate.
  ###########################################################################
  users.users.restic = {
    isSystemUser = true;
    group = "restic";
    home = "/var/lib/restic";
    createHome = true;
    # SFTP needs a real shell for `ssh … -s sftp` to work.
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [
      # meow's /etc/ssh/ssh_host_ed25519_key.pub. The comment still reads
      # root@servo — the key was generated before the rename and has not been
      # regenerated; it is the same host.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/oXzr8StBZWxQZcdtEDli7TvM6Mb1FF6CN6YMpDltx root@meow"
    ];
  };
  users.groups.restic = { };

  systemd.tmpfiles.rules = [
    "d /var/lib/restic 0700 restic restic -"
    "d /var/lib/restic/meow 0700 restic restic -"
  ];
}
