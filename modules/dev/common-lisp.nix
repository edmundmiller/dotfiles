# modules/dev/common-lisp.nix --- Common Lisp

{ pkgs, ... }: {

  my.packages = with pkgs; [ sbcl asdf lispPackages.quicklisp ];
}
