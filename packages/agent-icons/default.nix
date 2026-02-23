# packages/agent-icons/default.nix
#
# Custom font mapping AI agent logos to Private Use Area codepoints.
# Used with Ghostty's font-codepoint-map to render agent icons in tmux.
#
# Codepoints:
#   U+F5000 = claude
#   U+F5001 = amp
#   U+F5002 = opencode
#   U+F5003 = anthropic
{
  lib,
  python3Packages,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "agent-icons";
  version = "1.0.0";

  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: _type:
      let
        baseName = baseNameOf path;
      in
      baseName == "build-font.py" || baseName == "svgs" || lib.hasSuffix ".svg" baseName;
  };

  nativeBuildInputs = [ python3Packages.fonttools ];

  buildPhase = ''
    python3 build-font.py agent-icons.otf
  '';

  installPhase = ''
    mkdir -p $out/share/fonts/opentype
    cp agent-icons.otf $out/share/fonts/opentype/
  '';

  meta = with lib; {
    description = "Agent icon font (PUA codepoints for Claude, Amp, OpenCode, Anthropic)";
    license = licenses.cc0;
    platforms = platforms.all;
  };
}
