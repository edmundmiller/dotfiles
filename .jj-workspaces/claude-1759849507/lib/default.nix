{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) makeExtensible attrValues foldr;
  inherit (modules) mapModules;

  modules = import ./modules.nix {
    inherit lib;
    self.attrs = import ./attrs.nix {
      inherit lib;
      self = { };
    };
  };
  
  platform = import ./platform.nix {
    inherit lib pkgs inputs;
  };

  mylib = makeExtensible (
    self:
    with self;
    mapModules ./. (
      file:
      import file {
        inherit
          self
          lib
          pkgs
          inputs
          ;
      }
    )
  );
in
mylib.extend (_self: super: foldr (a: b: a // b) { } (attrValues super))
