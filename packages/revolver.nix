{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  zsh,
}:

stdenvNoCC.mkDerivation rec {
  pname = "revolver";
  version = "0.2.4";

  src = fetchFromGitHub {
    owner = "molovo";
    repo = "revolver";
    rev = "v${version}";
    sha256 = "sha256-UZwwCY2gIJmSP+jOBDAIkTpyEbNNtj0ZRdOB7osZM2w=";
  };

  nativeBuildInputs = [ zsh ];

  installPhase = ''
    mkdir -p $out/bin $out/share/revolver
    cp revolver $out/bin/revolver
    chmod +x $out/bin/revolver
  '';

  meta = with lib; {
    description = "A progress spinner for ZSH scripts";
    homepage = "https://github.com/molovo/revolver";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
