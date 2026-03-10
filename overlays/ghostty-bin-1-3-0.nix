# Overlay to pin ghostty-bin to 1.3.0 official macOS binary.
_final: prev: {
  ghostty-bin = prev.ghostty-bin.overrideAttrs (_old: rec {
    version = "1.3.0";
    src = prev.fetchurl {
      url = "https://release.files.ghostty.org/${version}/Ghostty.dmg";
      hash = "sha256-U/6Y5wmCEYAIwDuf2/XfJlUip/22vfoY630NTNMdDMU=";
    };
  });
}
