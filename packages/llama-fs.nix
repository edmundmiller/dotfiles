{
  lib,
  cacert,
  stdenvNoCC,
  fetchFromGitHub,
  fetchPypi,
  makeWrapper,
  python313,
}:

let
  agentops = python313.pkgs.buildPythonPackage rec {
    pname = "agentops";
    version = "0.4.21";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-R3Wcbf1upYutL3dkJX5HeMsuNK4YDO9kL2D1atztZRA=";
    };

    build-system = [ python313.pkgs.hatchling ];
    dependencies = with python313.pkgs; [
      aiohttp
      httpx
      opentelemetry-api
      opentelemetry-exporter-otlp-proto-http
      opentelemetry-instrumentation
      opentelemetry-sdk
      opentelemetry-semantic-conventions
      ordered-set
      packaging
      psutil
      pyyaml
      requests
      termcolor
      wrapt
    ];
    pythonRelaxDeps = [
      "packaging"
      "psutil"
      "termcolor"
    ];
    pythonImportsCheck = [ "agentops" ];
  };

  python = python313.withPackages (
    ps: with ps; [
      agentops
      asciitree
      colorama
      fastapi
      groq
      llama-index-core
      llama-index-readers-file
      ollama
      pydantic
      python-dotenv
      termcolor
      uvicorn
      watchdog
    ]
  );
in
stdenvNoCC.mkDerivation {
  pname = "llama-fs";
  version = "unstable-2025-08-08";

  src = fetchFromGitHub {
    owner = "iyaja";
    repo = "llama-fs";
    rev = "0a693717ca1845b3ae8c208b2929d987fcdabb81";
    hash = "sha256-7z6i8eFPmQ1Jx6+W8s5Zs5eRSJfMt7sqyXqaUzzN2tU=";
  };

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace src/loader.py \
      --replace-fail 'import weave' '# weave import removed: unused' \
      --replace-fail 'agentops.record_function("' 'agentops.task(name="' \
      --replace-fail 'agentops.record_tool("' 'agentops.tool(name="'
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/llama-fs" "$out/bin"
    cp server.py "$out/share/llama-fs/"
    cp -r src "$out/share/llama-fs/"
    makeWrapper ${python}/bin/uvicorn "$out/bin/llama-fs" \
      --set SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --add-flags "server:app --app-dir $out/share/llama-fs"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    cd "$out/share/llama-fs"
    export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
    ${python}/bin/python -c 'import server'
    "$out/bin/llama-fs" --help >/dev/null
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "Self-organizing file manager powered by Llama 3";
    homepage = "https://github.com/iyaja/llama-fs";
    license = licenses.mit;
    maintainers = with maintainers; [ edmundmiller ];
    mainProgram = "llama-fs";
    platforms = platforms.unix;
  };
}
