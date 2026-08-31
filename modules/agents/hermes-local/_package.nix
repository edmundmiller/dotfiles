{
  inputs,
  pkgs,
}:
assert pkgs.stdenv.hostPlatform.isDarwin;
let
  hermesFlake = inputs.agents-workspace.inputs.hermesAgent;
  hermesInputs = hermesFlake.inputs // {
    self = hermesFlake;
  };
  system = pkgs.stdenv.hostPlatform.system;

  # nixpkgs' packaged Apple libffi trampoline dylib is invalid on macOS 27.
  # Shadow only _ctypes with a copy that loads the system libffi. The stock
  # interpreter and unrelated Python packages remain unchanged.
  hermesPkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [
      (
        final: prev:
        let
          patchedCtypes =
            final.runCommand "python3.12-darwin-system-ctypes"
              {
                nativeBuildInputs = [ final.cctools ];
              }
              ''
                site_packages="$out/${prev.python312.sitePackages}"
                mkdir -p "$site_packages"

                set -- ${prev.python312}/lib/python3.12/lib-dynload/_ctypes.cpython-*.so
                test "$#" -eq 1
                target="$site_packages/$(basename "$1")"
                cp "$1" "$target"
                chmod u+w "$target"

                set -- $(otool -L "$target" | grep -F '/lib/libffi.' | awk '{ print $1 }')
                test "$#" -eq 1
                case "$1" in
                  /nix/store/*-libffi-*/lib/libffi.*.dylib) ;;
                  *) exit 1 ;;
                esac
                install_name_tool -change "$1" /usr/lib/libffi.dylib "$target"
              '';
        in
        {
          hermesPatchedCtypes = patchedCtypes;

          python312 = prev.python312.override {
            packageOverrides = _pyFinal: pyPrev: {
              h5py = pyPrev.h5py.overrideAttrs (old: {
                preCheck = (old.preCheck or "") + ''
                  export PYTHONPATH="${patchedCtypes}/${prev.python312.sitePackages}:''${PYTHONPATH:-}"
                '';
              });

              # cc-rs 1.2.48 can deadlock while probing Clang when stderr fills
              # before stdout is drained. Carry the upstream 1.2.49 fix only in
              # Tokenizers' vendored Cargo dependencies.
              tokenizers = pyPrev.tokenizers.overrideAttrs (old: {
                cargoDeps = old.cargoDeps.overrideAttrs (vendorOld: {
                  buildCommand = vendorOld.buildCommand + ''
                    patch -d "$out/source-registry-0/cc-1.2.48" -p1 \
                      < ${../../../overlays/hermes-agent/patches/tokenizers-cc-rs-1.2.48-detect-family-deadlock.patch}
                  '';
                });
              });
            };
          };
        }
      )
    ];
  };

  # Evaluate the upstream package module with the scoped package set so its
  # default package keeps the upstream full dependency groups as they evolve.
  hermesPackageModule = import (hermesFlake + /nix/packages.nix) {
    inputs = hermesInputs;
  };
  hermesPackage =
    (hermesPackageModule.perSystem {
      pkgs = hermesPkgs;
      inherit (hermesPkgs) lib;
      inputs' = {
        npm-lockfile-fix.packages.default = hermesFlake.inputs.npm-lockfile-fix.packages.${system}.default;
      };
    }).packages.default;
in
hermesPackage.overrideAttrs (old: {
  postFixup = (old.postFixup or "") + ''
    for program in hermes hermes-agent hermes-acp; do
      wrapProgram "$out/bin/$program" \
        --prefix PYTHONPATH : "${hermesPkgs.hermesPatchedCtypes}/${hermesPkgs.python312.sitePackages}"
    done
  '';

  passthru = (old.passthru or { }) // {
    hermesH5py = hermesPkgs.python312.pkgs.h5py;
    inherit (hermesPkgs) hermesPatchedCtypes;
    hermesPython = hermesPkgs.python312;
    hermesTokenizers = hermesPkgs.python312.pkgs.tokenizers;
  };
})
