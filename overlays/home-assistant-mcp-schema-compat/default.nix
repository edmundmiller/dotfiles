{ inputs }:
_final: prev:
let
  hassPkgs = import inputs.nixpkgs-hass {
    inherit (prev.stdenv.hostPlatform) system;
    overlays = [
      (final: base: {
        # Keep the 2026.11 packaging local until nixpkgs provides this release.
        home-assistant =
          final.callPackage
            (base.applyPatches {
              name = "home-assistant-2026.11-packaging";
              src = inputs.nixpkgs-hass + "/pkgs/servers/home-assistant";
              patches = [ ./patches/0002-package-home-assistant-2026.11.patch ];
            })
            {
              syrupySnapshotTestPatch = ./patches/0003-syrupy-lock-snapshot-test.patch;
            };
      })
    ];
  };
in
{
  inherit (hassPkgs) buildHomeAssistantComponent;
  home-assistant = hassPkgs.home-assistant.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/0001-skip-invalid-mcp-tool-schemas.patch
    ];
  });
}
