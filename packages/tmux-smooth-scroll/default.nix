{ rustPlatform, lib }:

rustPlatform.buildRustPackage {
  pname = "tmux-smooth-scroll";
  version = "0.1.0";

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "Smooth scrolling for tmux — single Rust binary, no per-line fork";
    homepage = "https://github.com/edmundmiller/dotfiles";
    license = licenses.mit;
    mainProgram = "tmux-smooth-scroll";
    platforms = platforms.unix;
  };
}
