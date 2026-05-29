{ lib, buildGo126Module, fetchFromGitHub }:

# motd's go.mod requires Go 1.26; nixpkgs default buildGoModule is still 1.25.
buildGo126Module rec {
  pname = "motd";
  version = "0.1.4";

  src = fetchFromGitHub {
    owner = "arne";
    repo = "motd";
    rev = "v${version}";
    hash = "sha256-MZCF6dpZBvNALL0HcsxZiDPSdJtKkay9KhtaBUSBgR4=";
  };

  vendorHash = "sha256-96G/2l2lKrndUCgAuYj6gyQooR3p/eSF4vV66T8A4Qw=";

  subPackages = [ "cmd/motd" ];

  ldflags = [
    "-s" "-w"
    "-X main.version=${version}"
  ];

  meta = {
    description = "Personal motd renderer (host info, services, updates)";
    homepage = "https://github.com/arne/motd";
    license = lib.licenses.mit;
    mainProgram = "motd";
  };
}
