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
      homebrew.taps = [
        {
          name = "saragordic/tap";
          trusted = true;
        }
      ];
      homebrew.casks = [
        "agentsview"
        "saragordic/tap/rooms"
        "screen-studio"
      ];
    }
  );
}
