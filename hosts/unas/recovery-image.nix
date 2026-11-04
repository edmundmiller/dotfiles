# Build independently of the host flake, with public keys supplied by the caller:
# nix-build hosts/unas/recovery-image.nix --argstr publicKeysFile /path/to/keys.pub
{ publicKeysFile }:
let
  upstream = builtins.getFlake "github:DeterminateSystems/nixos-iso/2b64f6cdd9baa8cda0909f46640bb81199ee6033";
  inherit (upstream.inputs.nixpkgs) lib;
  system = upstream.nixosConfigurations.x86_64-linux.install.extendModules {
    specialArgs.recoveryKeys = builtins.filter (line: line != "" && !(lib.hasPrefix "#" line)) (
      lib.splitString "\n" (builtins.readFile publicKeysFile)
    );
    modules = [ ./recovery.nix ];
  };
in
system.config.system.build.isoImage
