# modules/dev/rust.nix --- https://rust-lang.org

{ pkgs, ... }: {
  my = {
    packages = with pkgs; [ rustup llvmPackages.bintools ];

    env.RUSTUP_HOME = "$XDG_DATA_HOME/rustup";
    env.CARGO_HOME = "$XDG_DATA_HOME/cargo";
    env.PATH = [ "$CARGO_HOME/bin" ];

    alias.rs = "rustc";
    alias.rsp = "rustup";
    alias.ca = "cargo";
  };
}
