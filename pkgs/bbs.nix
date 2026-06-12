{ lib, buildGoModule, fetchgit }:

# bbs — SSH BBS (host service, runs as the dedicated `bbs` user).
#
# SCAFFOLD — NOT WIRED UP. Checked 2026-06-12: the source isn't on the forge
# (code.bas.es/arne/bbs is 404). modules/services/bbs.nix runs the vendor
# binary from /opt/bbs via the glibc loader instead. Once the repo is pushed:
# fill in src/hashes below and point the module's ExecStart at this package.
buildGoModule rec {
  pname = "bbs";
  version = "0.1.0";

  # TODO: confirm repo URL + pin a rev.
  src = fetchgit {
    url = "https://code.bas.es/arne/bbs";
    rev = "REPLACE_WITH_COMMIT_SHA"; # TODO
    hash = lib.fakeHash; # TODO
  };

  vendorHash = lib.fakeHash; # TODO

  meta = {
    description = "SSH BBS";
    mainProgram = "bbs";
    license = lib.licenses.unfree; # TODO: set actual license
  };
}
