{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  fzf,
  fd,
  bat,
  tree,
  zoxide,
  coreutils,
}:

stdenvNoCC.mkDerivation rec {
  pname = "tmux-file-picker";
  version = "0-unstable-2026-06-12";

  src = fetchFromGitHub {
    owner = "raine";
    repo = "tmux-file-picker";
    rev = "d1561a75aebfb50e5ad38facac684252014a44a0";
    hash = "sha256-JFtLsQBtoCXPFb+xa1/Edi6snUJPe05Io8qGpaX5cxw=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp tmux-file-picker $out/bin/
    chmod +x $out/bin/tmux-file-picker

    wrapProgram $out/bin/tmux-file-picker \
      --prefix PATH : ${
        lib.makeBinPath [
          fzf
          fd
          bat
          tree
          zoxide
          coreutils
        ]
      }
  '';

  meta = with lib; {
    description = "Tmux file picker for AI agents";
    homepage = "https://github.com/raine/tmux-file-picker";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
