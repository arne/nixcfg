# immich — photo/video library, restored from the Debian `cube` install.
#
# Native NixOS service, replacing the docker-in-Incus stack the box ran before
# (immich v2 on postgres:14-vectorchord0.4.3). The media tree itself never
# moved: it lives on the `fast` pool at /storage/photos and survived the
# reinstall untouched — only the Postgres database was restored, from
# /storage/migration/immich-db.sql.
#
# Postgres is managed by the immich module (services.postgresql). The database
# dump was taken under vchord 0.4.3; 25.11 ships 0.5.3, and the module detects
# that version change and reindexes automatically on activation.
#
# pgvecto.rs (`vectors`) is deliberately NOT enabled: immich v2 had already
# migrated to VectorChord, the dump requires only `vchord` + `vector`, and
# leaving it off is what allows PostgreSQL 17+ (the module asserts otherwise).
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

    database = {
      enable = true;
      enableVectorChord = true;
      enableVectors = false;
    };
  };
}
