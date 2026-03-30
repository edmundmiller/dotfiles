{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.skillkit;
in
{
  options.modules.shell.skillkit = {
    enable = mkBoolOpt false;
    packageSpec = mkOpt types.str "@crafter/skillkit@0.7.0";
  };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.skillkit-sync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          export DOTFILES="${config.dotfiles.dir}"
          export SKILLKIT_SPEC="${cfg.packageSpec}"
          export NPM_BIN="${pkgs.nodejs}/bin/npm"
          export PATCH_BIN="${pkgs.patch}/bin/patch"
          export SHA_BIN="${pkgs.coreutils}/bin/sha256sum"
          "$DOTFILES/bin/skillkit-sync"
        '';
      };
  };
}
