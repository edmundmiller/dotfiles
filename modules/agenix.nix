# modules/agenix.nix -- encrypt secrets in nix store
{
  options,
  config,
  inputs,
  lib,
  ...
}:
with builtins;
with lib;
with lib.my; let
  inherit (inputs) agenix;
  secretsDir = "${toString ../hosts}/${config.networking.hostName}/secrets";
  secretsFile = "${secretsDir}/secrets.nix";
in {
  imports = [agenix.nixosModules.age];
  environment.systemPackages = [agenix.packages.x86_64-linux.default];

  age = {
    secrets =
      if pathExists secretsFile
      then
        mapAttrs' (n: _:
          nameValuePair (removeSuffix ".age" n) {
            file = "${secretsDir}/${n}";
            owner = mkDefault config.user.name;
          }) (import secretsFile)
      else {};
    identityPaths =
      options.age.identityPaths.default
      ++ (filter pathExists [
        "${config.user.home}/.ssh/id_ed25519"
        "${config.user.home}/.ssh/id_rsa"
      ]);
  };
}
