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
# activation here, since 26.05 ships vchord 1.1.1.
#
# The former `database.enableVectorChord`/`enableVectors` toggles are GONE in
# 26.05 (mkRemovedOptionModule): pgvecto.rs is no longer packaged, so
# VectorChord is unconditional and there is nothing left to switch off. Setting
# either one is now an eval error, which is what broke this host on the bump.
#
# THE SERVER PACKAGE COMES FROM nixpkgs-unstable, deliberately — 26.05 ships
# immich 2.7.5, which nixpkgs marks INSECURE and refuses to evaluate:
# CVE-2026-59258, CVE-2026-82272, and upstream's "2.x.x will not receive
# further updates". There is no patched 2.x to move to, so the only options
# were waiving two CVEs with permittedInsecurePackages or taking 3.x early.
# Unstable has 3.2.4. (3.x reaches stable in 26.11, which is not released yet —
# no nixos-26.11 branch exists as of 2026-10-10 — so this override is what to
# drop once we bump to it.)
#
# ONLY THE PACKAGE IS OVERRIDDEN, not the module. The 26.05 module drives
# `cfg.package` and `cfg.package.machine-learning` without any version
# assertions, and the database side it configures is unchanged by this: both
# revs ship vectorchord 1.1.1, so nothing about the Postgres layout or the
# reindex trigger moves. Keeping the stable module avoids dragging unstable's
# postgresql 18 in behind it.
#
# ONE-WAY, AND IT TOUCHES THE RESTORED DATABASE: immich runs its own schema
# migrations at startup and 2.x -> 3.x is a major one. Rolling back to the
# previous generation does NOT roll the database back, and 2.7.5 will not start
# against a 3.x schema. /storage/migration/immich-db.sql is the floor.
{ config, pkgs, lib, inputs, ... }:

let
  unstable = import inputs.nixpkgs-unstable { inherit (pkgs) system; };
in
{
  services.immich = {
    enable = true;

    # immich 3.2.4 — see the header. Carries machine-learning as a passthru,
    # which the module picks up as `cfg.package.machine-learning`, so the
    # server and the ML worker stay from the same source.
    package = unstable.immich;

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
