{
  config,
  pkgs,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.bitwarden;
in
{
  options.modules.shell.bitwarden = with types; {
    enable = mkBoolOpt false;
    config = mkOpt attrs { };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      user.packages = with pkgs; [
        bitwarden
        bitwarden-cli
        unstable.goldwarden
      ];

      modules.shell.zsh.rcInit = "_cache bw completion --shell zsh; compdef _bw bw;";
    }

    # NixOS-only activation scripts (optionalAttrs on isDarwin to avoid defining non-existent options)
    (optionalAttrs (!isDarwin) (
      mkIf (cfg.config != { }) {
        system.userActivationScripts = {
          initBitwarden = ''
            ${concatStringsSep "\n" (mapAttrsToList (n: v: "bw config ${n} ${v}") cfg.config)}
          '';
        };
      }
    ))
  ]);
}
