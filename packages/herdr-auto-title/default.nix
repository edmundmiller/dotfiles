{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
  coreutils,
}:

stdenvNoCC.mkDerivation {
  pname = "herdr-auto-title";
  version = "0-unstable-2026-08-12";

  src = fetchFromGitHub {
    owner = "sh1ma";
    repo = "herdr-auto-title";
    rev = "aae70057b0c48b9d80aaecca77079879ce01f694";
    hash = "sha256-+2trh4At4yrkSb+C5fBBMzKzKH9HHtNq+QzjKfLdtsk=";
  };

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  postPatch = ''
    substituteInPlace install.sh \
      --replace-fail 'cp "$source_file" "$hook_file"' 'cp -f "$source_file" "$hook_file"'
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 herdr_auto_title.py "$out/libexec/herdr-auto-title/herdr_auto_title.py"
    install -Dm755 install.sh "$out/libexec/herdr-auto-title/install.sh"
    patchShebangs "$out/libexec/herdr-auto-title/install.sh"
    makeWrapper "$out/libexec/herdr-auto-title/install.sh" "$out/bin/herdr-auto-title-install" \
      --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          python3
        ]
      }

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    export HOME="$TMPDIR/home"
    "$out/bin/herdr-auto-title-install" --claude --codex >/dev/null
    "$out/bin/herdr-auto-title-install" --claude --codex >/dev/null
    ${lib.getExe python3} - "$HOME" <<'PY'
    import json
    import pathlib
    import sys

    home = pathlib.Path(sys.argv[1])
    for path in (home / ".claude/settings.json", home / ".codex/hooks.json"):
        data = json.loads(path.read_text())
        hooks = data["hooks"]["UserPromptSubmit"]
        matches = [
            hook
            for entry in hooks
            for hook in entry.get("hooks", [])
            if "herdr-auto-title.py" in str(hook.get("command", ""))
        ]
        assert len(matches) == 1, (path, matches)
    PY

    runHook postInstallCheck
  '';

  meta = {
    description = "Generate short Herdr tab titles from Claude Code and Codex prompts";
    homepage = "https://github.com/sh1ma/herdr-auto-title";
    license = lib.licenses.mit;
    mainProgram = "herdr-auto-title-install";
    platforms = lib.platforms.unix;
  };
}
