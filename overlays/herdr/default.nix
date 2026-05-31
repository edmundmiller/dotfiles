final: prev:
let
  inherit (prev) lib;
  isDarwin = final.stdenv.hostPlatform.isDarwin;
  sdk = "${final.apple-sdk_15}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.5.sdk";
  src = final.applyPatches {
    src = final.fetchFromGitHub {
      owner = "ogulcancelik";
      repo = "herdr";
      rev = "4219aec638cdd81efae6460c6fba28418925c37c";
      hash = "sha256-Y/cZeBqYvSxo/cWyvEJP1opG2diG2LUUFPRy/0yMSKk=";
    };
    patches = [
      ./patches/0001-worktree-post-create-command.patch
      ./patches/0002-add-dotfiles-cli-helpers.patch
      ./patches/0003-add-worktree-layout-subcommand.patch
      ./patches/0004-add-hunk-subcommand.patch
      ./patches/0005-fix-hermes-detection.patch
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
