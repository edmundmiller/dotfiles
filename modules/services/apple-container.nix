{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.appleContainer;
in
{
  options.modules.services.appleContainer = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (
    {
      assertions = [
        {
          assertion = isDarwin;
          message = "modules.services.appleContainer is only supported on Darwin";
        }
      ];
    }
    // optionalAttrs isDarwin {
      services.containerization.enable = true;
    }
  );
}
