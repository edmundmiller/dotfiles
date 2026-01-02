# modules/agenix.nix -- encrypt secrets in nix store
{
  options,
  config,
  inputs,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with builtins;
with lib;
with lib.my;
let
  inherit (inputs) agenix;
  # Shared secrets directory (cross-platform, for secrets used on multiple hosts)
  sharedSecretsDir = "${toString ../hosts}/shared/secrets";
  # NixOS host-specific secrets directory
  secretsDir =
    if isDarwin then ""
    else "${toString ../hosts}/${config.networking.hostName}/secrets";
  secretsFile =
    if isDarwin then ""
    else "${secretsDir}/secrets.nix";
in
{
  imports = if isDarwin then [ agenix.darwinModules.age ] else [ agenix.nixosModules.age ];

  environment.systemPackages = [ agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  age = mkMerge [
    # NixOS-only secrets configuration
    (optionalAttrs (!isDarwin) {
      secrets =
        let
          # Host-specific secrets from secrets.nix
          hostSecrets =
            if secretsFile != "" && pathExists secretsFile then
              mapAttrs' (
                n: _:
                nameValuePair (removeSuffix ".age" n) {
                  file = "${secretsDir}/${n}";
                  owner = mkDefault config.user.name;
                }
              ) (import secretsFile)
            else
              { };
          # Shared secrets (taskchampion-sync for taskwarrior)
          sharedSecrets = optionalAttrs config.modules.shell.taskwarrior.enable {
            taskchampion-sync = {
              file = "${sharedSecretsDir}/taskchampion-sync.age";
              owner = config.user.name;
              mode = "0400";
            };
          };
        in
        hostSecrets // sharedSecrets;
      identityPaths =
        options.age.identityPaths.default
        ++ (filter pathExists [
          "${config.user.home}/.ssh/id_ed25519"
          "${config.user.home}/.ssh/id_rsa"
        ]);
    })
  ];

  # Darwin: use home-manager's age module for user-level secrets
  # Use fixed paths so taskwarrior can reference them (no shell expansion needed)
  home-manager.users.${config.user.name} = mkIf isDarwin {
    imports = [ agenix.homeManagerModules.age ];

    age = {
      # Fixed mount points (taskwarrior include directive doesn't support shell expansion)
      secretsDir = "${config.user.home}/.local/share/agenix";
      secretsMountPoint = "${config.user.home}/.local/share/agenix.d";

      # SSH key used for decryption
      identityPaths = [ "${config.user.home}/.ssh/id_ed25519" ];

      # Shared secrets (available on all Darwin hosts)
      secrets = {
        taskchampion-sync = {
          file = "${sharedSecretsDir}/taskchampion-sync.age";
        };
        wakatime-api-key = {
          file = "${sharedSecretsDir}/wakatime-api-key.age";
        };
      };
    };
  };
}
