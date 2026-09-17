{ inputs }:
_final: prev:
let
  hassPkgs = import inputs.nixpkgs-hass {
    inherit (prev.stdenv.hostPlatform) system;
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
