{ lib, buildGoModule, fetchgit }:

# Nyheter — Norwegian news syndication server (host service; Caddy proxies
# nyheter.fismen.no → 127.0.0.1:8083, and the server listens on :8083).
#
# SCAFFOLD — NOT WIRED UP. Checked 2026-06-12: the source isn't on the forge
# (code.bas.es/arne/nyheter is 404). modules/services/nyheter.nix runs the
# vendor binary from /opt/nyheter instead (statically linked, works on NixOS).
# Once the repo is pushed: fill in src/hashes below and point the module's
# ExecStart at this package.
buildGoModule rec {
  pname = "nyheter";
  version = "0.1.0";

  # TODO: confirm repo URL + pin a rev (arne's forge at code.bas.es, like the
  # `launcher` flake input — adjust if it lives elsewhere).
  src = fetchgit {
    url = "https://code.bas.es/arne/nyheter";
    rev = "REPLACE_WITH_COMMIT_SHA"; # TODO
    hash = lib.fakeHash; # TODO: build once, paste the reported hash
  };

  vendorHash = lib.fakeHash; # TODO: build once, paste the reported hash

  # The unit runs ${nyheter}/bin/nyheter-server — make sure the produced binary
  # is named accordingly (adjust subPackages / ldflags to match the repo).
  # subPackages = [ "cmd/nyheter-server" ];

  meta = {
    description = "Norwegian news syndication server";
    mainProgram = "nyheter-server";
    license = lib.licenses.unfree; # TODO: set actual license
  };
}
