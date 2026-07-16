{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "teaterfestivalen";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "arne";
    repo = "teater";
    rev = "83d928c4f81f4e19b3be69144ad0d9debd736631";
    hash = "sha256-vvqEUTb8KU1XONTtTaOGsRsaGwfbzWPqQeQJUPtkqD0=";
  };

  vendorHash = "sha256-zWiLSkzhox3sXVsNBOdPKP0lZENCKT9xMnFk0tENPw0=";

  meta = {
    description = "Teaterfestivalen i Fjaler — festivalprogram";
    homepage = "https://github.com/arne/teater";
    license = lib.licenses.unfree;
    mainProgram = "teaterfestivalen";
  };
}
