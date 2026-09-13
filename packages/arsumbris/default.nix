{
  lib,
  node-lts,
  fetchurl,
  runCommand,
  writeShellApplication,
  git,
  python3,
  cargo,
  rustc,
  coreutils,
}:
let
  # Upstream's source workspaces require this exact pnpm, including nested calls.
  pnpmSource = fetchurl {
    url = "https://registry.npmjs.org/pnpm/-/pnpm-11.1.1.tgz";
    hash = "sha512-0f319zxhe2T6GlaoHDyN/g6WbjOmAQqiVrUXrne+Idk+Ba/8DeGoOw5PKdVp9otEaujwaM1yR8C7PfD7TXvfmg==";
  };
  pnpmFiles = runCommand "arsumbris-pnpm-11.1.1" { } ''
    mkdir -p "$out"
    tar -xzf ${pnpmSource} --strip-components=1 -C "$out"
  '';
  pnpm = writeShellApplication {
    name = "pnpm";
    text = ''
      exec ${node-lts}/bin/node ${pnpmFiles}/bin/pnpm.mjs "$@"
    '';
  };
in
writeShellApplication {
  name = "arsumbris";
  runtimeInputs = [
    node-lts
    pnpm
    git
    python3
    cargo
    rustc
    coreutils
  ];
  text = builtins.readFile ./arsumbris.sh;
  meta = {
    description = "Explicit source-workspace setup and launcher for Ars Umbris 0.0.1-alpha";
    homepage = "https://github.com/arsumbris/arsumbris";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    mainProgram = "arsumbris";
  };
}
