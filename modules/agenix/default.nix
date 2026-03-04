# modules/agenix.nix -- encrypt secrets in nix store
{
  options,
  config,
  inputs,
  lib,
  pkgs,
  isDarwin,
  hostName ? "",
  ...
}:
with builtins;
with lib;
with lib.my;
let
  inherit (inputs) agenix;
  # Shared secrets directory (cross-platform, for secrets used on multiple hosts)
  sharedSecretsDir = "${toString ../hosts}/shared/secrets";
  # Effective hostname for per-host secrets
  effectiveHostName = if isDarwin then hostName else config.networking.hostName;
  # NixOS host-specific secrets directory
  secretsDir = if isDarwin then "" else "${toString ../hosts}/${effectiveHostName}/secrets";
  secretsFile = if isDarwin then "" else "${secretsDir}/secrets.nix";
in
{
  imports = if isDarwin then [ agenix.darwinModules.age ] else [ agenix.nixosModules.age ];

  environment.systemPackages = [ agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  age = mkMerge [
    # NixOS-only secrets configuration
    (optionalAttrs (!isDarwin) {
      secrets =
        let
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
          # Shared secrets — only load secrets this host can decrypt
          sharedSecrets =
            let
              hostKeysFile = "${sharedSecretsDir}/host-keys.nix";
              hostKey =
                if pathExists hostKeysFile then (import hostKeysFile).${effectiveHostName} or null else null;
              allShared =
                if pathExists "${sharedSecretsDir}/secrets.nix" then
                  import "${sharedSecretsDir}/secrets.nix"
                else
                  { };
              filtered =
                if hostKey != null then filterAttrs (_: v: elem hostKey v.publicKeys) allShared else allShared;
            in
            mapAttrs' (
              n: _:
              nameValuePair (removeSuffix ".age" n) {
                file = "${sharedSecretsDir}/${n}";
                owner = mkDefault config.user.name;
              }
            ) filtered;
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
  # Note: Wrapping in mkIf first defers ${config.user.name} evaluation to avoid recursion
  home-manager.users = mkIf isDarwin {
    ${config.user.name} = {
      imports = [ agenix.homeManagerModules.age ];

      age = {
        secretsDir = "${config.user.home}/.local/share/agenix";
        secretsMountPoint = "${config.user.home}/.local/share/agenix.d";
        identityPaths = [ "${config.user.home}/.ssh/id_ed25519" ];

        secrets = {
          wakatime-api-key = {
            file = "${sharedSecretsDir}/wakatime-api-key.age";
          };
          openclaw-gateway-token = {
            file = "${sharedSecretsDir}/openclaw-gateway-token.age";
          };
        };
      };
    };
  };
}
