{ lib, buildGo126Module, fetchFromGitHub }:

# forge's go.mod requires Go 1.26; nixpkgs default buildGoModule is still 1.25.
buildGo126Module rec {
  pname = "forge";
  version = "0.5.1";

  src = fetchFromGitHub {
    owner = "git-pkgs";
    repo = "forge";
    rev = "v${version}";
    hash = "sha256-oLkaqnyCV8dOs33bz1FqhQT7A/smupk2Y5kaAuD1F3M=";
  };

  vendorHash = "sha256-HqO2GsPkpACAlNSm6VGoyAWKzWgkADmDrevLHIHNTaI=";

  subPackages = [ "cmd/forge" ];

  ldflags = [
    "-s" "-w"
    "-X github.com/git-pkgs/forge/internal/cli.Version=${version}"
  ];

  meta = {
    description = "Unified CLI for GitHub, GitLab, Gitea/Forgejo, and Bitbucket";
    homepage = "https://github.com/git-pkgs/forge";
    license = lib.licenses.mit;
    mainProgram = "forge";
  };
}
