final: prev:
let
  src = final.applyPatches {
    src = final.fetchFromGitHub {
      owner = "ogulcancelik";
      repo = "herdr";
      rev = "420925d141c8805e610eb0d62d49d8b9b483d961";
      hash = "sha256-pC/FFMWRK+VdOsUZlmKWADnbezdoy9ecEqZsSy9CJvw=";
    };
    patches = [ ../../patches/herdr-worktree-post-create-command.patch ];
  };
  herdrFromSource = final.callPackage "${src}/nix/package.nix" { };
in
{
  herdr = herdrFromSource.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + final.lib.optionalString final.stdenv.hostPlatform.isDarwin ''
        substituteInPlace build.rs \
          --replace-fail '.arg("build")' '.arg("build")
              .arg("-Dcpu=baseline")' \
          --replace-fail '.arg(format!("-Dtarget={zig_target}"))' ""
      '';
    env =
      (old.env or { })
      // final.lib.optionalAttrs final.stdenv.hostPlatform.isDarwin {
        LIBGHOSTTY_VT_OPTIMIZE = "ReleaseSafe";
      };
  });
}
