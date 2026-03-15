# Overlay to pin ghostty-bin to 1.3.1 official macOS binary.
_final: prev: {
  ghostty-bin = prev.ghostty-bin.overrideAttrs (_old: rec {
    version = "1.3.1";
    src = prev.fetchurl {
      url = "https://release.files.ghostty.org/${version}/Ghostty.dmg";
      hash = "sha256-GM/ysKbO6Q7q2cfTBk6AiiUqQLryFKp1LB7LeTuPX2k=";
    };
  });
}
