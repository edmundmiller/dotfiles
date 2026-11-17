{
  lib,
  stdenv,
  inputs,
  fetchFromGitHub,
  pkg-config,
  alsa-lib,
  fontconfig,
  luajit,
}:
let
  # Wasmtime 50 requires Rust >= 1.97; keep the host package set unchanged.
  rustPlatform = inputs.nixpkgs-jj.legacyPackages.${stdenv.hostPlatform.system}.rustPlatform;
in
rustPlatform.buildRustPackage {
  pname = "leaf-reader";
  version = "0.11.1";

  src = fetchFromGitHub {
    owner = "DeepanshuMishraa";
    repo = "leaf";
    rev = "1fd9573697c2e2507cff5ef07a4b6f93a06e5729";
    hash = "sha256-xG91g2AUTy6+nbj1T/yl6/XAiJgW/kz/Yh8SGmhMnb0=";
  };

  cargoHash = "sha256-p4cURyWVUVxTPJtQpHlaGtWFLlWQDnw7afeH8mxDBqg=";
  patches = [ ./patches/0001-declarative-rex-plugin.patch ];

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];
  buildInputs = [ fontconfig ] ++ lib.optionals stdenv.hostPlatform.isLinux [ alsa-lib ];
  nativeCheckInputs = [ luajit ];
  postCheck = ''
    luajit tests/rex.lua
  '';

  postInstall = ''
    mkdir -p "$out/share/leaf-reader"
    cp -r lua/leaf "$out/share/leaf-reader/"
  '';

  meta = {
    description = "Terminal document and diff reader with a native Rex palette";
    homepage = "https://github.com/DeepanshuMishraa/leaf";
    license = lib.licenses.mit;
    mainProgram = "leaf";
    platforms = lib.platforms.unix;
  };
}
