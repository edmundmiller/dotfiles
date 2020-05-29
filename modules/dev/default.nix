# modules/dev --- common settings for dev modules

{ pkgs, ... }: {
  imports = [
    ./cc.nix
    ./clojure.nix
    ./common-lisp.nix
    # ./godot.nix
    # ./haskell.nix
    ./java.nix
    # ./latex.nix
    ./lua.nix
    ./nixlang.nix
    ./node.nix
    ./python.nix
    ./R.nix
    ./rust.nix
    ./zsh.nix
  ];

  options = { };
  config = { };
}
