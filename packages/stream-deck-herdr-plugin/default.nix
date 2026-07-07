{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
}:

stdenv.mkDerivation {
  pname = "stream-deck-herdr-plugin";
  version = "0.1.0-unstable-2026-06-25";

  src = fetchFromGitHub {
    owner = "timvdhoorn";
    repo = "stream-deck-herdr-plugin";
    rev = "eaa23e57fde55205b9083c10f882ee4082893ffb";
    hash = "sha256-UmgOuyjywe52k5EpFzo3n0iupsSATLzCSfKZvskAPDs=";
  };

  nativeBuildInputs = [ bun ];

  postPatch = ''
    # Both managed macOS hosts use Ghostty for Herdr; bake that into the plugin
    # because Stream Deck launches plugins with a sparse GUI environment.
    substituteInPlace src/os/terminal.ts \
      --replace 'export const DEFAULT_TERMINAL_APP = "iTerm";' 'export const DEFAULT_TERMINAL_APP = "Ghostty";'

    # Stream Deck starts plugins from launchd, not an interactive shell, so the
    # upstream Homebrew-only PATH does not find Nix-installed `herdr` on these
    # hosts. Include the usual nix-darwin system and per-user profiles.
    substituteInPlace src/herdr/client.ts \
      --replace 'const PATH_EXTRA = "/opt/homebrew/bin:/usr/local/bin";' \
        'const PATH_EXTRA = "/run/current-system/sw/bin:/etc/profiles/per-user/edmundmiller/bin:/etc/profiles/per-user/emiller/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin";'

  '';

  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)
    bun install --frozen-lockfile
    bun run build

    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall

        mkdir -p "$out"
        cp -R dev.timvdhoorn.herdr-agents.sdPlugin "$out/"

        # Rollup leaves `ws` external. Keep it next to CodePath so the Stream Deck
        # Node runtime can resolve it even when it launches from the plugin's bin dir.
        mkdir -p "$out/dev.timvdhoorn.herdr-agents.sdPlugin/bin/node_modules"
        cp -R node_modules/ws "$out/dev.timvdhoorn.herdr-agents.sdPlugin/bin/node_modules/"

        mv "$out/dev.timvdhoorn.herdr-agents.sdPlugin/bin/plugin.js" \
          "$out/dev.timvdhoorn.herdr-agents.sdPlugin/bin/plugin-main.js"
        cat > "$out/dev.timvdhoorn.herdr-agents.sdPlugin/bin/plugin.js" <<'EOF'
    import { copyFileSync, mkdirSync } from "node:fs";
    import { homedir } from "node:os";
    import { dirname, join } from "node:path";
    import { fileURLToPath } from "node:url";

    const pluginDir = dirname(dirname(fileURLToPath(import.meta.url)));
    const runtimeDir = join(
      homedir(),
      "Library/Application Support/com.elgato.StreamDeck/NixRuntime/dev.timvdhoorn.herdr-agents",
    );
    mkdirSync(runtimeDir, { recursive: true });
    copyFileSync(join(pluginDir, "manifest.json"), join(runtimeDir, "manifest.json"));
    process.chdir(runtimeDir);

    await import("./plugin-main.js");
    EOF
        runHook postInstall
  '';

  meta = with lib; {
    description = "Elgato Stream Deck plugin mirroring herdr agent status";
    homepage = "https://github.com/timvdhoorn/stream-deck-herdr-plugin";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}
