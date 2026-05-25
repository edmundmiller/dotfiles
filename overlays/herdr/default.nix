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
                  --replace-fail '.arg(format!("-Dtarget={zig_target}"))' "" \
                  --replace-fail '.arg("-Demit-xcframework=false");' '.arg("-Demit-xcframework=false")
                      .arg("--sysroot")
                      .arg("${final.apple-sdk_15}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.5.sdk")
                      .arg("--libc")
                      .arg("darwin-libc.txt");'
                cat > darwin-libc.txt <<LIBC
        include_dir=${final.apple-sdk_15}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.5.sdk/usr/include
        sys_include_dir=${final.apple-sdk_15}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.5.sdk/usr/include
        crt_dir=${final.apple-sdk_15}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.5.sdk/usr/lib
        msvc_lib_dir=
        kernel32_lib_dir=
        gcc_dir=
        LIBC
      '';
    nativeBuildInputs =
      (old.nativeBuildInputs or [ ])
      ++ final.lib.optionals final.stdenv.hostPlatform.isDarwin [
        final.apple-sdk_15
        final.cctools
      ];
    env =
      (old.env or { })
      // final.lib.optionalAttrs final.stdenv.hostPlatform.isDarwin {
        LIBGHOSTTY_VT_OPTIMIZE = "ReleaseSafe";
        SDKROOT = "${final.apple-sdk_15}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.5.sdk";
      };
  });
}
