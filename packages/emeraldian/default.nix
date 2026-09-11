{
  autoPatchelfHook,
  fetchurl,
  gcc,
  lib,
  stdenvNoCC,
}:
let
  version = "0.5.0";
  sources = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-WzMouzqXtJqyCNIqd6LU7HzLMi2SyxlwnUW6Nj6s/Sg=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-mSbOad+4bo72BGBfI/ihTje7Wedtm9CLNOrGOJkhStA=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-eHO9mxxQVHHf4LHfuMWD7Aeb9BY3Cet8CyreiR/ZS7o=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "emeraldian: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "emeraldian";
  inherit version;

  src = fetchurl {
    url = "https://github.com/iamrohithrnair/emeraldian/releases/download/v${version}/emeraldian-${source.target}.tar.gz";
    inherit (source) hash;
  };

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ gcc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 emeraldian "$out/bin/emeraldian"
    runHook postInstall
  '';

  meta = {
    description = "Terminal UI for Obsidian vaults, with a graph and an assistant";
    homepage = "https://github.com/iamrohithrnair/emeraldian";
    changelog = "https://github.com/iamrohithrnair/emeraldian/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.gpl3Plus;
    mainProgram = "emeraldian";
    platforms = builtins.attrNames sources;
  };
}
