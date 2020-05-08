# modules/dev --- common settings for dev modules

{ pkgs, ... }: {
  imports = [
    ./cc.nix
    ./clojure.nix
    ./common-lisp.nix
    # ./godot.nix
    # ./haskell.nix
    # ./latex.nix
    ./lua.nix
    ./nixlang.nix
    ./node.nix
    ./python.nix
    ./rust.nix
    ./zsh.nix
  ];

  options = { };
  config = { };
}
