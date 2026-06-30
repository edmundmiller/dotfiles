{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.herald;
in
{
  options.modules.shell.herald = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (
    optionalAttrs isDarwin {
      homebrew = {
        taps = [ "herald-email/herald" ];
        brews = [ "herald" ];
      };
    }
  );
}
