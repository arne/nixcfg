{ config, pkgs, lib, ... }:

{
  # beets — command-line music tagger/organiser. `beet import <dir>` matches a
  # folder against MusicBrainz, writes corrected tags, and copies the result
  # into /srv/music using the library's Artist/Album (Year)/NN - Title layout.
  # Workflow: drop an album in ~/incoming, run `beet import ~/incoming/<album>`,
  # confirm the match; the original stays put (import.copy = yes).
  #
  # beets 2.5.1 is flagged insecure in nixpkgs: CVE-2026-42052 is an XSS in its
  # optional `web` plugin, which our config doesn't enable. The flag is pinned
  # to the version, not gated on `web` actually being built — so beets-minimal
  # carries it too. Rather than a system-wide nixpkgs.config permit, we clear
  # the flag on beets alone, keeping the "we accept this CVE" decision next to
  # the package it concerns. (useGlobalPkgs = true rules out nixpkgs.config in
  # this HM module anyway; overrideAttrs sidesteps that since it's per-package.)
  home.packages = [
    (pkgs.beets.overrideAttrs (o: {
      meta = o.meta // { knownVulnerabilities = []; };
    }))
  ];

  # Config + path format travel with the package. See files/beets/config.yaml.
  xdg.configFile."beets/config.yaml".source = ../files/beets/config.yaml;
}
