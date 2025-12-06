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
  # On Darwin, agenix might not be fully compatible yet - skip secrets loading
  # On NixOS, use the hostname-based secrets directory
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
      identityPaths =
        options.age.identityPaths.default
        ++ (filter pathExists [
          "${config.user.home}/.ssh/id_ed25519"
          "${config.user.home}/.ssh/id_rsa"
        ]);
    })
  ];
}
