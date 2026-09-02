{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## gonic — music streaming at https://music.fismen.no.
  ##
  ## Replaces navidrome (removed in the same commit). The split of concerns is
  ## deliberate: beets (home/beets.nix) manages the library, gonic only serves
  ## it. gonic's own web UI is an ADMIN PANEL — users, last.fm wiring, scan
  ## triggers — not a player. That is the point: listening happens in real
  ## clients (Symfonium, Supersonic, play:Sub…), not in a browser.
  ##
  ## Auth is gonic's own accounts and deliberately NOT the tinyauth snippet: a
  ## Subsonic client cannot follow an SSO redirect, so forward_auth in front of
  ## this vhost would break every phone app. gonic implements the standard
  ## Subsonic salt+token scheme, so client compatibility is as broad as it gets
  ## (this was the deciding factor over LMS, which supports API keys only).
  ##
  ## Folder vs tag browsing is a CLIENT-side choice, not a server setting —
  ## gonic serves both trees (getIndexes/getMusicDirectory for folders,
  ## getArtists/getAlbumList for tags) simultaneously. Pick folder mode in the
  ## client; beets guarantees the one-album-per-directory layout it needs.
  ##
  ## Binds loopback (the module's default listen-addr, not the upstream
  ## 0.0.0.0:4747), so caddy proxies 127.0.0.1:4747 and the port never needs a
  ## firewall hole — unlike oink, where navidrome binds 0.0.0.0 and is opened
  ## on tailscale0 only.
  ##
  ## MANUAL STEP after the first switch: browse to https://music.fismen.no and
  ## log in as admin/admin, then CHANGE THAT PASSWORD IMMEDIATELY. gonic seeds
  ## a default admin account and this vhost is WAN-facing.
  ###########################################################################
  services.gonic = {
    enable = true;
    settings = {
      # /srv/music is arne:users 0755 — arne (via beets) owns and writes the
      # files, gonic gets it as a BindReadOnlyPath and can only read.
      music-path = [ "/srv/music" ];

      # Both are asserted by the module and bind-mounted into the sandbox, so
      # they must exist before the unit starts (tmpfiles below). Podcasts are
      # unused today; the path is required regardless.
      podcast-path = "/var/lib/gonic/podcasts";
      playlists-path = "/var/lib/gonic/playlists";

      # beets writes to /srv/music out of band, so let gonic notice by itself
      # rather than relying on a client-triggered scan. The inotify watcher
      # catches imports promptly; the hourly interval is the backstop for
      # events it misses (large moves can overflow the watch queue).
      scan-at-start-enabled = true;
      scan-watcher-enabled = true;
      scan-interval = 60;
    };
  };

  # StateDirectory=gonic creates /var/lib/gonic but not these children, and
  # systemd resolves BindPaths sources on the host BEFORE entering the sandbox
  # — a missing directory fails the unit at start rather than degrading.
  systemd.tmpfiles.settings.gonicDirs = {
    "/var/lib/gonic/podcasts"."d" = { mode = "0700"; user = "root"; group = "root"; };
    "/var/lib/gonic/playlists"."d" = { mode = "0700"; user = "root"; group = "root"; };
  };
}
