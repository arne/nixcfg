# immich — photo/video library, restored from the Debian `cube` install.
#
# Native NixOS service, replacing the docker-in-Incus stack the box ran before
# (immich v2 on postgres:14-vectorchord0.4.3). The media tree itself never
# moved: it lives on the `fast` pool at /storage/photos and survived the
# reinstall untouched — only the Postgres database was restored, from
# /storage/migration/immich-db.sql.
#
# Postgres is managed by the immich module (services.postgresql). The database
# dump was taken under vchord 0.4.3 and the module reindexes automatically when
# it detects a vchord version change on activation — expect that on the first
# 26.05 activation, since the shipped vchord moved again.
#
# The former `database.enableVectorChord`/`enableVectors` toggles are GONE in
# 26.05 (mkRemovedOptionModule): pgvecto.rs is no longer packaged, so
# VectorChord is unconditional and there is nothing left to switch off. Setting
# either one is now an eval error, which is what broke this host on the bump.
{ config, pkgs, lib, ... }:

{
  services.immich = {
    enable = true;

    # The pre-existing library on the fast pool. Contents (library, thumbs,
    # encoded-video, profile, backups) are chowned to the immich user; they
    # were uid 1000 under the container's idmap.
    mediaLocation = "/storage/photos";

    # Reachable on the LAN and over the tailnet, as it was on Debian.
    host = "0.0.0.0";
    port = 2283;
    openFirewall = true;

    database.enable = true;
  };
}
