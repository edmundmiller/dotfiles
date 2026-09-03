{
  fetchurl,
  lib,
  nodejs,
  prettier,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "hermes-tailscale";
  version = "0.0.2";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/Adolanium/hermes-tailscale/ad205aafdc57bf8f8b5cea29848b3312f5b3b3bf/plugin.js";
    hash = "sha256-TRTBwfI1uOP5XNEa8eeCBto4XMEOZ2UETYmMg1zJFjI=";
  };

  nativeBuildInputs = [
    nodejs
    prettier
  ];
  dontUnpack = true;

  buildPhase = ''
    runHook preBuild

    # Upstream ships one minified file. Format it deterministically so the
    # security patch remains readable and fails cleanly if the pin drifts.
    prettier "$src" --parser babel > plugin.js
    patch -p1 < ${./patches/0001-restrict-remote-dashboard.patch}

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck

    prettier --check plugin.js
    node ${./test-chunk-transport.mjs} ./plugin.js
    grep -Fq 'hermes-json snapshot' plugin.js
    grep -Fq 'Taildrop requires Desktop local terminal support.' plugin.js
    grep -Fq 'label: "Copy ssh"' plugin.js

    for forbidden in \
      'cdn.jsdelivr.net' \
      'esm.sh' \
      'import(' \
      'script.src' \
      'serve --bg' \
      'serve reset' \
      '--exit-node' \
      'switch --list --json' \
      'switchAccount' \
      'sendFileShell' \
      'id: "publish"' \
      'jsx(SshAskBar' \
      'jsx(SshOverlay' \
      'children: "SSH"'; do
      if grep -Fq -- "$forbidden" plugin.js; then
        echo "Forbidden Hermes Tailscale behavior remains: $forbidden" >&2
        exit 1
      fi
    done

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    install -Dm0444 plugin.js "$out/plugin.js"

    runHook postInstall
  '';

  passthru = {
    inherit (finalAttrs) version;
    upstreamRevision = "ad205aafdc57bf8f8b5cea29848b3312f5b3b3bf";
  };

  meta = {
    description = "Read-only Hermes Desktop view of a Tailscale tailnet";
    homepage = "https://github.com/Adolanium/hermes-tailscale";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
