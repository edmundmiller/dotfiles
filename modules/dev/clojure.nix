# modules/dev/clojure.nix --- https://clojure.org/
#
# I don't use clojure. Perhaps one day...

{ pkgs, ... }: {
  imports = [
    ./.
    ./java.nix # for being hosted on jvm
    ./node.nix # for being hosted on nodejs
  ];
  my.packages = with pkgs; [
    clojure
    # Dev tools
    leiningen
    joker
    unstable.clojure-lsp
  ];
}
