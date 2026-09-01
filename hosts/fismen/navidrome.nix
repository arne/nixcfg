{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## Navidrome — music streaming at https://music.fismen.no.
  ##
  ## Speaks the Subsonic API (/rest/*), so native clients work alongside the
  ## built-in web UI. Auth is Navidrome's OWN accounts, deliberately NOT the
  ## (tinyauth) snippet: a Subsonic client cannot follow an SSO redirect, so
  ## forward_auth in front of this vhost would break every phone app.
  ##
  ## Binds loopback only. Caddy on this host terminates TLS and proxies to
  ## 127.0.0.1:4533, so 4533 never needs a firewall hole (unlike oink, where
  ## navidrome binds 0.0.0.0 and is opened on tailscale0 only).
  ##
  ## MANUAL STEP — pre-create the library dir before the first switch:
  ##   sudo install -d -o arne -g users -m 0755 /srv/music
  ## The module's tmpfiles rule for MusicFolder is ":700" (create-only), so it
  ## leaves an existing dir's owner/mode alone: arne owns and manages the
  ## files, the navidrome service user only reads them.
  ###########################################################################
  services.navidrome = {
    enable = true;
    settings = {
      Address = "127.0.0.1";
      Port = 4533;
      MusicFolder = "/srv/music";

      # Public share links (Sharing menu in the web UI). Anyone holding a
      # share URL can stream that content without an account — that is the
      # point of the feature, but it is the one unauthenticated path into
      # this server. Links expire after DefaultShareExpiration (1 year).
      EnableSharing = true;

      # Codec used when a client asks for a reduced bitrate without naming a
      # format (upstream default is "opus"). Every Subsonic client can play
      # mp3; opus support is patchier on older ones.
      #
      # NOTE: this sets the FORMAT, not the rate. The 256 kbps figure lives in
      # the `transcoding` table (the seeded "mp3 audio" profile ships 192),
      # which is app state, not config — see core/stream/decider.go:164,
      # `maxBitRate := trc.DefaultBitRate`. It is bumped to 256 in the DB;
      # EnableTranscodingConfig stays false so the UI cannot edit transcoding
      # commands, which are shell strings run by the server.
      DefaultDownsamplingFormat = "mp3";

      # Built-in DB backups. Users, playlists, ratings and play counts live in
      # navidrome.db and are NOT re-derivable from the audio files. This is
      # corruption insurance only — it lands on the same ZFS mirror as
      # everything else, and fismen has no off-host backup of its own (it is
      # the restic TARGET for meow, see restic-target.nix).
      Backup = {
        Path = "/var/lib/navidrome/backup";
        Schedule = "@daily";
        Count = 7;
      };
    };
  };

  # The module's tmpfiles rules cover DataFolder / CacheFolder / MusicFolder but
  # NOT Backup.Path, and systemd resolves BindPaths sources on the host before
  # entering the sandbox — a missing /var/lib/navidrome/backup would fail the
  # unit at start rather than degrade gracefully. StateDirectory=navidrome only
  # creates the parent.
  systemd.tmpfiles.settings.navidromeBackup."/var/lib/navidrome/backup"."d" = {
    mode = "700";
    user = config.services.navidrome.user;
    group = config.services.navidrome.group;
  };

  # ND_PASSWORDENCRYPTIONKEY — without it navidrome stores user passwords in
  # cleartext in navidrome.db, which is not acceptable for a WAN-facing
  # instance. mkForce because the module sets EnvironmentFile from its own
  # `environmentFile` option as a hard (non-tolerant) path; the `-` prefix is
  # the caddy.nix / services.nix idiom, so a boot that beats sops bring-up
  # does not fail the unit.
  #
  # NOTE: the key must be in place BEFORE the first user is created. Changing
  # or losing it later leaves every stored password undecryptable.
  systemd.services.navidrome.serviceConfig.EnvironmentFile =
    lib.mkForce "-/run/secrets/navidrome/env";
}
