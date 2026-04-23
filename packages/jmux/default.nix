{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  makeWrapper,
  tmux,
  git,
  python3,
}:

stdenv.mkDerivation {
  pname = "jmux";
  version = "0.13.0-unstable-2026-04-22";

  src = fetchFromGitHub {
    owner = "jarredkenny";
    repo = "jmux";
    rev = "43e500b6dc424a55d228dec9a7fb31f85b0d6937";
    hash = "sha256-5qiJkjeylKPlcpAdK1lPia5+qQRW/BGrYupYhxGKPiY=";
  };

  nativeBuildInputs = [
    bun
    makeWrapper
    python3
  ];

  postPatch = ''
    python <<'PY'
from pathlib import Path

path = Path("src/input-router.ts")
text = path.read_text()
text = text.replace(
    "export class InputRouter {\n",
    "const resolvePrefixByte = (): string => {\n"
    "  const raw = (typeof process !== \"undefined\" ? process.env.JMUX_PREFIX_KEY : undefined) ?? \"C-a\";\n"
    "  const normalized = raw.toLowerCase();\n"
    "  if (normalized === \"c-c\" || normalized === \"ctrl-c\") return \"\\x03\";\n"
    "  return \"\\x01\";\n"
    "};\n\n"
    "export class InputRouter {\n",
)
text = text.replace(
    "  private panelFilterActive = false;\n",
    "  private panelFilterActive = false;\n  private readonly prefixByte = resolvePrefixByte();\n",
)
text = text.replace(
    "    // Ctrl-a p interception: detect prefix + p to toggle palette\n    // Ctrl-a is forwarded to tmux (so other prefix bindings work),\n    // but if next byte is \"p\" we intercept it before tmux sees it.\n",
    "    // Prefix interception: detect prefix + p/n/i/g/... for jmux UI actions.\n    // The prefix byte is configurable via JMUX_PREFIX_KEY so it can track tmux.\n",
)
text = text.replace(
    "      } else if (data === \"\\x01\") {\n",
    "      } else if (data === this.prefixByte) {\n",
)
text = text.replace(
    "        // Only forward Ctrl-a to PTY when tmux is focused (not when diff panel is focused)\n",
    "        // Only forward the configured prefix byte to PTY when tmux is focused.\n",
)
path.write_text(text)
PY
  '';

  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)
    bun install --frozen-lockfile

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appDir=$out/lib/jmux
    mkdir -p "$appDir" "$out/bin"
    cp -r bin src config skills node_modules package.json bun.lock "$appDir"/

    makeWrapper ${bun}/bin/bun $out/bin/jmux \
      --set-default JMUX_PREFIX_KEY C-c \
      --add-flags "$appDir/bin/jmux" \
      --prefix PATH : ${lib.makeBinPath [ tmux git ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "jmux wrapped to honor Ctrl-c as the tmux/jmux prefix in this dotfiles setup";
    homepage = "https://github.com/jarredkenny/jmux";
    license = licenses.mit;
    mainProgram = "jmux";
    platforms = platforms.unix;
  };
}
