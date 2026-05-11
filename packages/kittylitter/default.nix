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
    rev = "20af82321e1a10bc0393319ea195ab5557351145";
    hash = "sha256-n9on4GRYk7iTUMy9XWQ7XDzkfIFeOyULgC9pTenQbxY=";
  };
in
rustPlatform.buildRustPackage rec {
  pname = "kittylitter";
  version = "0.2.9-patched";

  src = fetchFromGitHub {
    owner = "dnakov";
    repo = "litter";
    rev = "v0.2.9";
    hash = "sha256-o47orApOTTQRC7wA1Qw3E4Rqcs6OX24qljh6xPkVUZs=";
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

  cargoHash = "sha256-wkQ1dk3+woNxv5CrY6iVGEJy8OuDRG/QcbUShXAda/M=";

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
