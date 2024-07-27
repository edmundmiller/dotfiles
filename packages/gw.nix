{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "gw";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "kcleal";
    repo = "gw";
    rev = "v${version}";
    hash = "sha256-MmHCPdux0hiz9aguH07yYpdXvOFOOSICgZW4WE37WPE=";
  };

  meta = with lib; {
    description = "Genome browser and variant annotation";
    homepage = "https://github.com/kcleal/gw";
    license = licenses.mit;
    maintainers = with maintainers; [edmundmiller];
    mainProgram = "gw";
    platforms = platforms.all;
  };
}
