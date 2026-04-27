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
  version = "0.15.0";

  src = fetchFromGitHub {
    owner = "jarredkenny";
    repo = "jmux";
    rev = "v0.15.0";
    hash = "sha256-QLytzMzDUKdJddQ9Qao2xSO0C7jDfQIwOeJNNZy6pA4=";
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
        "const resolveNewSessionKey = (): string =>\n"
        "  ((typeof process !== \"undefined\" ? process.env.JMUX_NEW_SESSION_KEY : undefined) ?? \"M\").slice(0, 1);\n\n"
        "export class InputRouter {\n",
    )
    text = text.replace(
        "  private panelFilterActive = false;\n",
        "  private panelFilterActive = false;\n  private readonly prefixByte = resolvePrefixByte();\n  private readonly newSessionKey = resolveNewSessionKey();\n",
    )
    text = text.replace(
        "    // Ctrl-a p interception: detect prefix + p to toggle palette\n    // Ctrl-a is forwarded to tmux (so other prefix bindings work),\n    // but if next byte is \"p\" we intercept it before tmux sees it.\n",
        "    // Prefix interception: detect prefix + p/N/i/g/... for jmux UI actions.\n    // The prefix byte is configurable via JMUX_PREFIX_KEY so it can track tmux.\n",
    )
    text = text.replace(
        "      } else if (data === \"\\x01\") {\n",
        "      } else if (data === this.prefixByte) {\n",
    )
    text = text.replace(
        "        // Only forward Ctrl-a to PTY when tmux is focused (not when diff panel is focused)\n",
        "        // Only forward the configured prefix byte to PTY when tmux is focused.\n",
    )
    text = text.replace(
        "        if (data === \"n\") {\n",
        "        if (data === this.newSessionKey) {\n",
    )
    path.write_text(text)

    help_path = Path("src/main.ts")
    help_text = help_path.read_text()
    for before, after in [
        ("  Ctrl-a n                 New session / worktree\n", "  Prefix M                 New session / worktree\n"),
        ("  Ctrl-a c                 New window\n", "  Prefix c                 New window\n"),
        ("  Ctrl-a z                 Toggle pane zoom\n", "  Prefix z                 Toggle pane zoom\n"),
        ("  Ctrl-a Arrows            Resize panes\n", "  Prefix Arrows            Resize panes\n"),
        ("  Ctrl-a p                 Command palette\n", "  Prefix p                 Command palette\n"),
        ("  Ctrl-a g                 Toggle diff panel (on/off)\n", "  Prefix g                 Toggle diff panel (on/off)\n"),
        ("  Ctrl-a z                 Zoom diff panel (split ↔ full, when focused)\n", "  Prefix z                 Zoom diff panel (split ↔ full, when focused)\n"),
        ("  Ctrl-a Tab               Switch focus (tmux ↔ diff)\n", "  Prefix Tab               Switch focus (tmux ↔ diff)\n"),
        ("  Ctrl-a i                 Settings\n", "  Prefix i                 Settings\n"),
        ('[{ text: "Ctrl-a", attrs: g }, { text: " then ", attrs: n }, { text: "n", attrs: g }, { text: "          New session", attrs: n }],\n',
         '[{ text: "Prefix", attrs: g }, { text: " ", attrs: n }, { text: "M", attrs: g }, { text: "               New session", attrs: n }],\n'),
        ('[{ text: "Ctrl-a", attrs: g }, { text: " then ", attrs: n }, { text: "c", attrs: g }, { text: "          New window (tab)", attrs: n }],\n',
         '[{ text: "Prefix", attrs: g }, { text: " ", attrs: n }, { text: "c", attrs: g }, { text: "               New window (tab)", attrs: n }],\n'),
        ('[{ text: "Ctrl-a", attrs: g }, { text: " then ", attrs: n }, { text: "|", attrs: g }, { text: "          Split pane horizontally", attrs: n }],\n',
         '[{ text: "Prefix", attrs: g }, { text: " ", attrs: n }, { text: "|", attrs: g }, { text: "               Split pane horizontally", attrs: n }],\n'),
        ('[{ text: "Ctrl-a", attrs: g }, { text: " then ", attrs: n }, { text: "-", attrs: g }, { text: "          Split pane vertically", attrs: n }],\n',
         '[{ text: "Prefix", attrs: g }, { text: " ", attrs: n }, { text: "-", attrs: g }, { text: "               Split pane vertically", attrs: n }],\n'),
        ('[{ text: "Ctrl-a", attrs: g }, { text: " then ", attrs: n }, { text: "p", attrs: g }, { text: "          Command palette", attrs: n }],\n',
         '[{ text: "Prefix", attrs: g }, { text: " ", attrs: n }, { text: "p", attrs: g }, { text: "               Command palette", attrs: n }],\n'),
        ('[{ text: "1.", attrs: c }, { text: " Try ", attrs: n }, { text: "Ctrl-a p", attrs: g }, { text: " to open the command palette", attrs: n }],\n',
         '[{ text: "1.", attrs: c }, { text: " Try ", attrs: n }, { text: "Prefix p", attrs: g }, { text: " to open the command palette", attrs: n }],\n'),
    ]:
        help_text = help_text.replace(before, after)
    help_path.write_text(help_text)
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
      --set-default JMUX_NEW_SESSION_KEY M \
      --add-flags "$appDir/bin/jmux" \
      --prefix PATH : ${
        lib.makeBinPath [
          tmux
          git
        ]
      }

    runHook postInstall
  '';

  meta = with lib; {
    description = "jmux wrapped to honor Ctrl-c and keep prefix+n on next-window in this dotfiles setup";
    homepage = "https://github.com/jarredkenny/jmux";
    license = licenses.mit;
    mainProgram = "jmux";
    platforms = platforms.unix;
  };
}
