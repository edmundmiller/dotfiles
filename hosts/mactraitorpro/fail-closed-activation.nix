{ inputs, lib, ... }:
let
  guardActivationFragment = import ./_lib/fail-closed-tcc-reset.nix {
    inherit lib;
    upstream = inputs.nix-darwin.outPath;
  };
in
{
  # Transform the option before write-text derives .source from config.text.
  options.system.activationScripts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options.text = lib.mkOption {
            apply = guardActivationFragment name;
          };
        }
      )
    );
  };
}
