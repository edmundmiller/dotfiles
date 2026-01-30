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
  version = "unstable-2025-12-21";

  src = fetchFromGitHub {
    owner = "raine";
    repo = "tmux-file-picker";
    rev = "0473f7abe87b95bc008e1cbfd16578e9cee93565";
    hash = "sha256-Uz+88f3RG7dBangOg0RLQxuE9f49TpMOcQkTtauzPQU=";
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
