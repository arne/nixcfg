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
      # Beszel hub state (hosts/meow/beszel.nix). data.db holds the OIDC client
      # secret, the superuser, and the system inventory; id_ed25519 is the hub
      # key every agent's KEY is pinned to — regenerating it re-breaks the whole
      # fleet. None of that is in this repo, so without this a reinstall of meow
      # loses it. The real dir, not the /var/lib/beszel-hub symlink: DynamicUser
      # puts state under /var/lib/private, and restic archives a symlink as a
      # symlink rather than following it. restic runs as root, so the 0700
      # private dir is readable.
      "/var/lib/private/beszel-hub/beszel_data"
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
      # SQLite shared-memory index — pure runtime scratch, rebuilt when the DB
      # is next opened, and always mid-write. The -wal is kept so recent commits
      # aren't lost; SQLite replays it on restore. data.db is a live WAL-mode
      # file, so as with hass a snapshot taken during a write can be torn — the
      # prior daily snapshot is the fallback, and the config here changes rarely
      # (the fleet-critical id_ed25519 is written once and then static).
      "/var/lib/private/beszel-hub/beszel_data/*.db-shm"
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
