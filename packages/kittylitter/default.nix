{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  zlib,
}:

let
  alleycatSrc = fetchFromGitHub {
    owner = "dnakov";
    repo = "alleycat";
    rev = "94e79a6d0f92838d63971a6fc01210728234a871";
    hash = "sha256-LpxQiIAk0hOLLC8shPyixgexiXHz7QUoFK0PrTisxik=";
  };
in
rustPlatform.buildRustPackage rec {
  pname = "kittylitter";
  version = "0.3.0-patched";

  src = fetchFromGitHub {
    owner = "dnakov";
    repo = "litter";
    rev = "v0.3.0";
    hash = "sha256-gMr1sTs/4hTr5YhYUS4sPCyFQ7wM+2pWDB+35qwHgNw=";
  };

  cargoRoot = "services/kittylitter";
  buildAndTestSubdir = "services/kittylitter";

  postPatch = ''
    cp -R ${alleycatSrc} alleycat
    chmod -R u+w alleycat
    patch -d alleycat -p1 < ${./patches/0001-pi-bridge-local-hydration-and-ui-camelcase.patch}

    substituteInPlace services/kittylitter/Cargo.toml \
      --replace-fail 'alleycat = { git = "https://github.com/dnakov/alleycat.git", branch = "main" }' \
                     'alleycat = { path = "../../alleycat/crates/alleycat" }'
  '';

  cargoHash = "sha256-2+X1k1RNlS/ClSok3uh6LQZSd9MsiIqB4lxg2Upyegg=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    openssl
    zlib
  ];

  doCheck = false;

  meta = with lib; {
    description = "Patched kittylitter/alleycat daemon with Pi local session hydration compatibility";
    homepage = "https://github.com/dnakov/litter";
    license = licenses.gpl3Only;
    platforms = platforms.unix;
    mainProgram = "kittylitter";
  };
}
