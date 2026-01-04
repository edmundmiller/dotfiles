{
  pkgs,
  lib,
  ...
}:

pkgs.stdenvNoCC.mkDerivation {
  pname = "tmux-opencode-status";
  version = "enhanced-1.1.0";

  # No src fetch - all files are local
  src = ./.;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/scripts

    # Copy the main tmux plugin script
    cp opencode-status.tmux $out/
    chmod +x $out/opencode-status.tmux

    # Copy the enhanced status detection script
    cp opencode_status.sh $out/scripts/
    chmod +x $out/scripts/opencode_status.sh

    runHook postInstall
  '';

  meta = {
    description = "Enhanced OpenCode status monitor for tmux with finished state detection";
    homepage = "https://github.com/IFAKA/tmux-opencode-status";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
