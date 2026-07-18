{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.mo;
in
{
  options.modules.shell.mo = with types; {
    enable = mkBoolOpt false;
    purgePaths = mkOpt' (listOf str) [ ] ''
      Project scan directories for `mo purge`, written to
      $XDG_CONFIG_HOME/mole/purge_paths (one path per line).
    '';
  };

  config = mkIf cfg.enable {
    # Mole (mo) is distributed via Homebrew only.
    homebrew.brews = [ "mole" ];

    home.configFile = mkIf (cfg.purgePaths != [ ]) {
      "mole/purge_paths".text = concatMapStringsSep "\n" (p: p) cfg.purgePaths + "\n";
    };
  };
}
