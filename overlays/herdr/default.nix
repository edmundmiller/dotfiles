final: prev:
let
  inherit (prev) lib;
  isDarwin = final.stdenv.hostPlatform.isDarwin;
  sdk = "${final.apple-sdk_15}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.5.sdk";
  src = final.applyPatches {
    src = final.fetchFromGitHub {
      owner = "ogulcancelik";
      repo = "herdr";
      rev = "dbad2e54bb9e36138275fecad8d4978752fc4426";
      hash = "sha256-DjCSwhRMBRE9lSvjpX6m8IpoEgUbOP1jcmeXMlQlSQY=";
    };
    patches = [
      ./patches/0001-libghostty-bench-gated.patch
      ./patches/0006-update-cargo-hash.patch
    ];
  };
  herdrFromSource = final.callPackage "${src}/nix/package.nix" { };
  patchedHerdr = herdrFromSource.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + lib.optionalString isDarwin ''
                substituteInPlace build.rs \
                  --replace-fail '.arg("build")' '.arg("build")
                      .arg("-Dcpu=baseline")' \
                  --replace-fail '.arg(format!("-Dtarget={zig_target}"))' "" \
                  --replace-fail '.arg(format!("-Dversion-string={version_string}"))' '.arg(format!("-Dversion-string={version_string}"))
                      .arg("--sysroot")
                      .arg("${sdk}")
                      .arg("--libc")
                      .arg("darwin-libc.txt")'
                cat > vendor/libghostty-vt/darwin-libc.txt <<LIBC
        include_dir=${sdk}/usr/include
        sys_include_dir=${sdk}/usr/include
        crt_dir=${sdk}/usr/lib
        msvc_lib_dir=
        kernel32_lib_dir=
        gcc_dir=
        LIBC
      '';
    nativeBuildInputs =
      (old.nativeBuildInputs or [ ])
      ++ lib.optionals isDarwin [
        final.apple-sdk_15
        final.cctools
      ];
    env =
      (old.env or { })
      // lib.optionalAttrs isDarwin {
        LIBGHOSTTY_VT_OPTIMIZE = "ReleaseSafe";
        SDKROOT = sdk;
      };
  });
  herdr = if isDarwin then patchedHerdr else prev.llm-agents.herdr;
in
{
  llm-agents = (prev.llm-agents or { }) // {
    inherit herdr;
  };
}
