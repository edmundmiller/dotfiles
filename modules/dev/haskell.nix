# modules/dev/haskell.nix --- Haskell

{ pkgs, ... }: {
  imports = [ ./. ];

  my.packages = with pkgs; [
    cabal-install
    ghc
    # unstable.haskellPackages.ghc-mod
    haskellPackages.cabal2nix
    haskellPackages.hoogle
    haskellPackages.stack
    hlint
  ];
}
