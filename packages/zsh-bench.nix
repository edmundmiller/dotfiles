{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "zsh-bench";
  version = "0-unstable-2026-04-27";

  src = fetchFromGitHub {
    owner = "romkatv";
    repo = "zsh-bench";
    rev = "28b1b1bc888159f0a2cf50f9d29381758341aba1";
    hash = "sha256-dsHGpDTweDqJdLhO/9th2kDt56crfjqkTKBilEi9RaY=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Install full repo structure — zsh-bench resolves self_dir via ZSH_SCRIPT:A:h
    mkdir -p $out/share/zsh-bench
    cp -r internal configs dbg human-bench zsh-bench $out/share/zsh-bench/
    chmod -R +x $out/share/zsh-bench/internal/ $out/share/zsh-bench/dbg/ 2>/dev/null || true

    # Symlink main script into bin (zsh :A resolves through symlinks)
    mkdir -p $out/bin
    ln -s $out/share/zsh-bench/zsh-bench $out/bin/zsh-bench

    runHook postInstall
  '';

  meta = {
    description = "Benchmark for interactive zsh";
    homepage = "https://github.com/romkatv/zsh-bench";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
