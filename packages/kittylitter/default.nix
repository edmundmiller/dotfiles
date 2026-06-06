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
    rev = "3c6dfe2c6b060864d8cb0fcae58f73a6ed1ea10f";
    hash = "sha256-jV8apGihLHN1My2zLM9BCWoWGXWdruZoRaL6+Jf9Ypw=";
  };
in
rustPlatform.buildRustPackage rec {
  pname = "kittylitter";
  version = "0.3.4-patched";

  src = fetchFromGitHub {
    owner = "dnakov";
    repo = "litter";
    rev = "v0.3.4";
    hash = "sha256-T8Jjf9DUmqCthty1WaTRC/igFloCOpqUbKrk3diSR+w=";
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

  cargoHash = "sha256-Fs4+e23JMtDdEnkqLRrlkQoHmXS3L3FXxuGaoXZX5yA=";

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
