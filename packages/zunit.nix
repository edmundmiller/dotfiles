{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  zsh,
  makeWrapper,
  revolver,
}:

stdenvNoCC.mkDerivation rec {
  pname = "zunit";
  version = "0.8.2";

  src = fetchFromGitHub {
    owner = "zunit-zsh";
    repo = "zunit";
    rev = "v${version}";
    sha256 = "sha256-JlUb5omhy6uAhgva674FvDZ8E9AJ1tO5Ki7jJ6sDqjc=";
  };

  nativeBuildInputs = [
    zsh
    makeWrapper
  ];

  buildPhase = ''
    # Patch out revolver dependency check (not needed in CI/TAP mode)
    # Original: $(type revolver >/dev/null 2>&1) || ...
    # Replace with: true || ... (always succeeds, skips the check)
    sed -i 's/\$(type revolver .*2>&1)/true/' src/zunit.zsh

    # Run the build script to compile zunit
    zsh build.zsh
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp zunit $out/bin/zunit
    chmod +x $out/bin/zunit

    # Symlink revolver into zunit's bin so it's found via $PATH
    ln -s ${revolver}/bin/revolver $out/bin/revolver
  '';

  meta = with lib; {
    description = "A powerful unit testing framework for ZSH";
    homepage = "https://zunit.xyz";
    license = licenses.mit;
    platforms = platforms.all;
    maintainers = [ ];
  };
}
