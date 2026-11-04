{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.tinybar;
in
{
  options.modules.desktop.apps.tinybar.enable = mkBoolOpt false;

  # The popover upgrades Tinybar with `brew upgrade --cask` from this tap.
  # Leave `greedy` unset. nix-darwin writes `greedy:` only when it is true,
  # and that flag tells `brew bundle` to upgrade a self-updating cask during
  # activation. Hosts already pass `--no-upgrade` and set cleanup to "none".
  # Declaring the cask keeps a later `cleanup = "uninstall"` from removing it.
  # Homebrew 6 skips an untrusted third-party tap, so the tap is trusted.
  config = optionalAttrs isDarwin (
    mkIf cfg.enable {
      homebrew.taps = [
        {
          name = "thiloreintjes/tinybar";
          trusted = true;
        }
      ];
      homebrew.casks = [ "thiloreintjes/tinybar/tinybar" ];
    }
  );
}
