{
  lib,
  rustPlatform,
  jujutsu,
  gh,
  makeWrapper,
  pkg-config,
  openssl,
  zlib,
  libgit2,
}:

rustPlatform.buildRustPackage {
  pname = "jut";
  version = "0.1.0";

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    openssl
    zlib
    libgit2
  ];

  nativeCheckInputs = [ jujutsu ];

  # Integration tests need a real jj repo + git, skip in sandbox
  doCheck = false;

  # Wrap with jj and gh in PATH
  postInstall = ''
    wrapProgram $out/bin/jut \
      --prefix PATH : ${
        lib.makeBinPath [
          jujutsu
          gh
        ]
      }
  '';

  meta = with lib; {
    description = "GitButler-inspired CLI for Jujutsu (jj)";
    longDescription = ''
      A CLI tool inspired by GitButler's UX, built for Jujutsu (jj).
      Provides short CLI IDs, --json output, --status-after, the rub
      universal primitive, and PR creation via gh (no GitHub app required).
    '';
    homepage = "https://github.com/edmundmiller/dotfiles";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "jut";
    platforms = platforms.unix;
  };
}
