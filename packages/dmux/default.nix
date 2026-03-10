{
  lib,
  stdenvNoCC,
  nodejs,
  bash,
}:

stdenvNoCC.mkDerivation {
  pname = "dmux";
  version = "0.1.0";

  src = ./.;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib
    install -Dm755 bin/dmux $out/bin/dmux
    install -Dm755 bin/dmux-ai-infer $out/bin/dmux-ai-infer
    install -Dm644 lib/dmux-openrouter-shim.cjs $out/lib/dmux-openrouter-shim.cjs

    substituteInPlace $out/bin/dmux \
      --replace-fail "@BASH@" "${bash}/bin/bash" \
      --replace-fail "@INFER_BIN@" "$out/bin/dmux-ai-infer" \
      --replace-fail "@SHIM_PATH@" "$out/lib/dmux-openrouter-shim.cjs"

    substituteInPlace $out/bin/dmux-ai-infer \
      --replace-fail "@NODE@" "${nodejs}/bin/node"

    runHook postInstall
  '';

  meta = with lib; {
    description = "dmux wrapper with pi/opencode inference shim for OpenRouter AI calls";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "dmux";
  };
}
