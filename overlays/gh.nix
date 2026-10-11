# Overlay to pin gh to 2.100.0 for `--attach` on pr/issue create/edit/comment
# (added in 2.99.0). 2.101+ needs Go >= 1.27.0, but the locked nixpkgs only
# ships go_1_27 1.27rc1; drop this once nixpkgs gh reaches 2.99.
_final: prev: {
  gh = prev.gh.overrideAttrs (_old: rec {
    version = "2.100.0";
    src = prev.fetchFromGitHub {
      owner = "cli";
      repo = "cli";
      tag = "v${version}";
      hash = "sha256-9tnSQPSqllE+Ke6LKyNbnOF1drzdEwesEuPdmWD1X5c=";
    };
    vendorHash = "sha256-ZqUs2BnasF3QBX0I2Sxh2A/CnO61Vy6gRn1hkf0n9AY=";
  });
}
