# Build independently of the host flake with the approved login inventory:
# nix-build hosts/unas/recovery-image.nix
# Optional replacement public-key file: --argstr publicKeysFile /path/to/keys.pub
{
  publicKeysFile ? null,
}:
let
  upstream = builtins.getFlake "github:DeterminateSystems/nixos-iso/2b64f6cdd9baa8cda0909f46640bb81199ee6033";
  inherit (upstream.inputs.nixpkgs) lib;
  approvedKeys = import ../../config/ssh/authorized-keys.nix;
  system = upstream.nixosConfigurations.x86_64-linux.install.extendModules {
    specialArgs.recoveryKeys =
      if publicKeysFile == null then
        approvedKeys.ownerKeys ++ approvedKeys.unasMachineKeys
      else
        builtins.filter (line: line != "" && !(lib.hasPrefix "#" line)) (
          lib.splitString "\n" (builtins.readFile publicKeysFile)
        );
    modules = [ ./recovery.nix ];
  };
in
system.config.system.build.isoImage
