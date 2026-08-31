{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libnl,
  gcc-unwrapped,
}:

let
  version = "2025.9.0";
  owner = "home-assistant-libs";
  repo = "matter-linux-ota-provider";

  # Only x86-64-linux is used (NUC). aarch64-linux asset exists if needed later.
  src = fetchurl {
    url = "https://github.com/${owner}/${repo}/releases/download/${version}/chip-ota-provider-app-x86-64";
    hash = "sha256-RVDfevZSnkYgRj0cASf4MOwkBMgXrUxjQ7KeMs7AFE4=";
  };
in
stdenv.mkDerivation {
  pname = "chip-ota-provider-app";
  inherit version;

  inherit src;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    libnl
    gcc-unwrapped.lib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/chip-ota-provider-app
    runHook postInstall
  '';

  meta = with lib; {
    description = "Matter OTA Provider app for serving firmware updates to Matter devices";
    homepage = "https://github.com/${owner}/${repo}";
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    license = licenses.asl20;
    maintainers = [ ];
    mainProgram = "chip-ota-provider-app";
    platforms = [ "x86_64-linux" ];
  };
}
