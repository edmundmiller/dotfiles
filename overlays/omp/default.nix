final: prev:
let
  omp = prev.llm-agents.omp.overrideAttrs (
    old:
    let
      src = final.applyPatches {
        inherit (old) src;
        patches = [
          ./patches/0001-add-herdr-hunk-internal-urls.patch
          ./patches/0002-add-nextflow-ast-grep-language.patch
        ];
      };
    in
    {
      inherit src;
      cargoDeps = final.rustPlatform.fetchCargoVendor {
        name = "omp-${old.version}-cargo-vendor";
        inherit src;
        hash = "sha256-AUBzWh0hu+If/2+M/L6jYZ1tY7LefBvH+5i80DHnflo=";
      };
      postInstall =
        (old.postInstall or "")
        + final.lib.optionalString final.stdenv.hostPlatform.isDarwin ''
          for binary in "$out/lib/omp/omp" "$out"/lib/omp/pi_natives.*.node; do
            [ -e "$binary" ] && /usr/bin/codesign -f -s - "$binary"
          done
        '';
    }
  );
in
{
  llm-agents = (prev.llm-agents or { }) // {
    inherit omp;
  };
}
