{
  isDarwin,
  lib,
  ...
}:
{
  config = lib.mkIf isDarwin {
    home-manager.sharedModules = [
      (
        { lib, ... }:
        {
          home.activation.darwinBashHeredocCompatibility = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
            # Bash 5.3 normally writes small heredocs to a pipe sized at
            # build time. Darwin can provide a smaller pipe under pressure,
            # so retain Bash 5.0's tempfile behavior during activation.
            export BASH_COMPAT=50
          '';
        }
      )
    ];
  };
}
