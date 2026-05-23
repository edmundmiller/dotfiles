# modules/desktop/macos/brew.nix
#
# Homebrew-managed macOS desktop applications shared across Darwin hosts.
{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
let
  cfg = config.modules.desktop.macos;
in
{
  config = optionalAttrs isDarwin (
    mkIf cfg.enable {
      homebrew.casks = [
        "agentsview"
        "screen-studio"
      ];
    }
  );
}
