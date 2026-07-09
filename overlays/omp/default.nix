final: prev:
let
  omp = prev.llm-agents.omp.overrideAttrs (old: {
    src = final.applyPatches {
      inherit (old) src;
      patches = [
        ./patches/0001-add-herdr-hunk-internal-urls.patch
      ];
    };
    postInstall =
      (old.postInstall or "")
      + final.lib.optionalString final.stdenv.hostPlatform.isDarwin ''
        for binary in "$out/lib/omp/omp" "$out"/lib/omp/pi_natives.*.node; do
          [ -e "$binary" ] && /usr/bin/codesign -f -s - "$binary"
        done
      '';
  });
in
{
  llm-agents = (prev.llm-agents or { }) // {
    inherit omp;
  };
}
