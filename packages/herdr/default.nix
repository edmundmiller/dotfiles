{
  lib,
  rustPlatform,
  inputs,
  pkg-config,
  zig,
  stdenv,
  apple-sdk_15,
}:

rustPlatform.buildRustPackage rec {
  pname = "herdr";
  version = "0.5.4";

  src = inputs.herdr-repo;

  cargoHash = "sha256-Y9lXxeE1ochoCdQZDUZNlitwjCHtce2sdTvMZCcipkk=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = lib.optionals stdenv.isDarwin [ apple-sdk_15 ];

  preBuild = ''
    export PATH=${zig}/bin:${apple-sdk_15}/usr/bin:$PATH
    export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
    export DEVELOPER_DIR=${apple-sdk_15}/Platforms/MacOSX.platform/Developer
    export SDKROOT=${apple-sdk_15}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.5.sdk
    export NIX_LDFLAGS="-L$SDKROOT/usr/lib ''${NIX_LDFLAGS:-}"
  '';

  meta = with lib; {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://github.com/ogulcancelik/herdr";
    license = licenses.agpl3Plus;
    mainProgram = "herdr";
    platforms = platforms.unix;
  };
}
