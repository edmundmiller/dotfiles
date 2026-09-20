final: prev:
let
  inherit (prev) lib;
  isDarwin = final.stdenv.hostPlatform.isDarwin;
  sdk = "${final.apple-sdk_15}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.5.sdk";
  src = final.applyPatches {
    src = final.fetchFromGitHub {
      owner = "herdrdev";
      repo = "herdr";
      rev = "065ef9d6a531c49fb8bee7e818ef837065b21ee9"; # v0.9.1
      hash = "sha256-N6+kprfWRyh0AkAiopkGsNXUGGORyPVFHEaDHCpGQs8=";
    };
    patches = [
      ./patches/0007-worktree-actions-use-focused-pane-cwd.patch # bead: dotfiles-y5ag
      ./patches/0008-ignore-zero-terminal-resize.patch # bead: dotfiles-1t6d
      ./patches/0009-defer-background-tab-resize.patch # bead: dotfiles-0qcg
      ./patches/0014-macos-aiff-notification-sounds.patch
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
  herdr = patchedHerdr;
in
{
  llm-agents = (prev.llm-agents or { }) // {
    inherit herdr;
  };
}
