# modules/dev/haskell.nix --- Haskell

{ pkgs, ... }: {
  imports = [ ./. ];

  my.packages = with pkgs; [
    cabal-install
    ghc
    # unstable.haskellPackages.ghc-mod
    haskellPackages.hoogle
    hlint
  ];
}
