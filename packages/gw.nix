{
  lib,
  stdenv,
  fetchFromGitHub,
  mesa,
  fontconfig,
  htslib,
  glfw,
  curl,
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
  skia = fetchFromGitHub {
    owner = "JetBrains";
    repo = "skia-build";
    rev = "m93-87e8842e8c";
    hash = "sha256-kyaQS8KHNHj7zJGEsZu90mgdNbCvu8wofLDi1iAXpM0=";
  };

  # https://kcleal.github.io/gw/docs/install/Linux.html#building-from-source
  buildInputs = [
    mesa # libgl1-mesa-dev
    fontconfig # libfontconfig-dev
    htslib # libhts-dev
    glfw
    curl
  ];

  # preBuild = ''
  #   make prep
  # '';

  # cp gw /usr/local/bin
  meta = with lib; {
    description = "Genome browser and variant annotation";
    homepage = "https://github.com/kcleal/gw";
    license = licenses.mit;
    maintainers = with maintainers; [edmundmiller];
    mainProgram = "gw";
    platforms = platforms.all;
  };
}
