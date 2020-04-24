# modules/dev/haskell.nix --- Haskell
let
  all-hies =
    import (fetchTarball "https://github.com/infinisil/all-hies/tarball/master")
    { };
in { pkgs, ... }: {
  imports = [ ./. ];

  my.packages = with pkgs; [
    (all-hies.selection { selector = p: { inherit (p) ghc865; }; })
    cabal-install
    ghc
    shake
    # unstable.haskellPackages.ghc-mod
    haskellPackages.cabal2nix
    haskellPackages.hoogle
    haskellPackages.stack
    hlint
  ];
}
