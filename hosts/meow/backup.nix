{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## Backups — restic, meow → fismen over SFTP on the tailnet.
  ##
  ## WHY THIS EXISTS: meow is deliberately a single ext4 NVMe with no mirror
  ## and no ZFS (see flake.nix), so unlike fismen/oink it has neither
  ## redundancy nor snapshots. /var/lib/hass accumulates every automation,
  ## integration credential and long-lived token in the house — losing the
  ## disk means rebuilding all of it by hand.
  ##
  ## AUTH: no SSH key in sops. restic runs as root, so it authenticates with
  ## meow's existing /etc/ssh/ssh_host_ed25519_key — the same key sops uses to
  ## decrypt. fismen trusts it via hosts/fismen/restic-target.nix. Only the
  ## repository password is a secret.
  ##
  ## NOT BACKED UP: /mnt/form (3.6 TB media archive). It would not fit on
  ## fismen's 960 GB mirror, and it is re-acquirable; the automation state is
  ## not. If that archive matters, it needs its own answer — a second local
  ## disk or a cheap cloud bucket, not this repo's Hetzner box.
  ##
  ## RESTORE:
  ##   restic -r sftp:restic@fismen.little-lenok.ts.net:/var/lib/restic/meow snapshots
  ##   restic -r … restore latest --target /
  ## (with RESTIC_PASSWORD_FILE=/run/secrets/restic/password)
  ###########################################################################
  services.restic.backups.meow = {
    repository = "sftp:restic@fismen.little-lenok.ts.net:/var/lib/restic/meow";
    passwordFile = config.sops.secrets."restic/password".path;
    initialize = true;

    paths = [
      "/var/lib/hass"
      "/var/lib/esphome"
    ];

    exclude = [
      # The recorder database is a LIVE SQLite file — snapshotting it while
      # HA is running can capture a torn write, and it is the least valuable
      # part of the state (sensor history, not configuration). Everything
      # that actually matters lives in /var/lib/hass/.storage.
      "/var/lib/hass/home-assistant_v2.db"
      "/var/lib/hass/home-assistant_v2.db-wal"
      "/var/lib/hass/home-assistant_v2.db-shm"
      # Regenerable / noise.
      "/var/lib/hass/home-assistant.log*"
      "/var/lib/hass/tts"
      "/var/lib/hass/deps"
      "/var/lib/esphome/.esphome/build"
    ];

    # The host key is root-owned; restic's ssh needs to be pointed at it
    # explicitly since it runs with a bare environment. accept-new rather than
    # `yes` so the very first run can't deadlock on an unknown host key, while
    # still pinning it against later changes.
    extraOptions = [
      "sftp.command='${pkgs.openssh}/bin/ssh -i /etc/ssh/ssh_host_ed25519_key -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes restic@fismen.little-lenok.ts.net -s sftp'"
    ];

    timerConfig = {
      OnCalendar = "daily";
      # Spread the load; fismen also serves other things.
      RandomizedDelaySec = "1h";
      Persistent = true;
    };

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];
  };
}
