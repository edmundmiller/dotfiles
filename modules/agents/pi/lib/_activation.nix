{
  cfg,
  pkgs,
  hmLib,
  escapeShellArg,
  secretRefsJson,
  honchoEnvJson,
  opBin,
  opReadTimeoutSeconds,
}:
let
  dotenvMaterializer = pkgs.writers.writePython3 "pi-dotenv-materialize" { } ''
    import json
    import os
    import pathlib
    import subprocess
    import sys


    target = pathlib.Path(sys.argv[1])
    refs_path = pathlib.Path(sys.argv[2])
    plain_path = pathlib.Path(sys.argv[3])
    dotenv_path = pathlib.Path(sys.argv[4])
    op_bin = sys.argv[5]
    op_read_timeout_seconds = int(sys.argv[6])

    refs = json.loads(refs_path.read_text(encoding="utf-8"))
    plain = json.loads(plain_path.read_text(encoding="utf-8"))
    managed_keys = set(refs) | set(plain)
    existing_lines = []
    if dotenv_path.exists():
        existing_lines = dotenv_path.read_text(encoding="utf-8").splitlines()

    existing_values = {}
    kept_lines = []
    for line in existing_lines:
        key, sep, rest = line.partition("=")
        if sep:
            existing_values[key] = rest
        if sep and key in managed_keys:
            continue
        kept_lines.append(line)

    rendered_lines = list(kept_lines)
    for key, value in plain.items():
        if value:
            rendered_lines.append(f"{key}={value}")

    failed_keys = []
    empty_keys = []
    preserved_keys = []
    for key, ref in refs.items():
        try:
            value = subprocess.check_output(
                [op_bin, "read", ref],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=op_read_timeout_seconds,
            ).rstrip("\n")
        except Exception:
            fallback = existing_values.get(key, "")
            if fallback:
                preserved_keys.append(f"{key} ({ref})")
                rendered_lines.append(f"{key}={fallback}")
                continue
            failed_keys.append(f"{key} ({ref})")
            continue

        if not value:
            fallback = existing_values.get(key, "")
            if fallback:
                preserved_keys.append(f"{key} ({ref})")
                rendered_lines.append(f"{key}={fallback}")
                continue
            empty_keys.append(f"{key} ({ref})")
            continue

        rendered_lines.append(f"{key}={value}")

    if failed_keys:
        sample = ", ".join(failed_keys[:5])
        extra = (
            ""
            if len(failed_keys) <= 5
            else f" (+{len(failed_keys) - 5} more)"
        )
        print(
            "warning: failed to read "
            f"{len(failed_keys)} pi secret(s) from 1Password: "
            f"{sample}{extra}",
            file=sys.stderr,
        )

    if empty_keys:
        sample = ", ".join(empty_keys[:5])
        extra = (
            ""
            if len(empty_keys) <= 5
            else f" (+{len(empty_keys) - 5} more)"
        )
        print(
            f"warning: {len(empty_keys)} pi secret(s) resolved empty "
            f"from 1Password: {sample}{extra}",
            file=sys.stderr,
        )

    if preserved_keys:
        sample = ", ".join(preserved_keys[:5])
        extra = (
            ""
            if len(preserved_keys) <= 5
            else f" (+{len(preserved_keys) - 5} more)"
        )
        print(
            "warning: preserving "
            f"{len(preserved_keys)} existing pi secret(s) because "
            "1Password did not return a fresh value: "
            f"{sample}{extra}",
            file=sys.stderr,
        )

    content = "\n".join(rendered_lines)
    if content:
        content += "\n"

    target.write_text(content, encoding="utf-8")
    os.chmod(target, 0o600)
  '';
in
{
  pi-extension-conflict-cleanup = hmLib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ext_dir="$HOME/.pi/agent/extensions"
    rm -f "$ext_dir/context.ts" "$ext_dir/context.js"
    rm -rf "$HOME/.cache/npm/lib/node_modules/@howaboua/pi-codex-conversion"
    rmdir "$HOME/.cache/npm/lib/node_modules/@howaboua" 2>/dev/null || true

    rm -f "$ext_dir/guardrails.json"
    rm -rf "$HOME/.cache/npm/lib/node_modules/@aliou/pi-guardrails"
    rmdir "$HOME/.cache/npm/lib/node_modules/@aliou" 2>/dev/null || true
  '';

  pi-dotenv-secrets = hmLib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dotenv_target="$HOME/.pi/agent/.env"

    if [ ! -s ${escapeShellArg secretRefsJson} ]; then
      :
    elif ! command -v ${escapeShellArg opBin} >/dev/null 2>&1; then
      echo "warning: 1Password CLI unavailable; skipping pi dotenv materialization" >&2
    elif ! ${pkgs.coreutils}/bin/timeout 5 ${opBin} vault list >/dev/null 2>&1; then
      echo "warning: 1Password unavailable (locked or closed); preserving existing pi secrets" >&2
    else
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${dotenvMaterializer} "$tmp" ${escapeShellArg secretRefsJson} ${escapeShellArg honchoEnvJson} "$dotenv_target" ${escapeShellArg opBin} ${toString opReadTimeoutSeconds}
      ${pkgs.coreutils}/bin/install -m 0600 "$tmp" "$dotenv_target"
      ${pkgs.coreutils}/bin/rm -f "$tmp"
    fi
  '';

  pi-memory-remote = hmLib.mkIf (cfg.memoryRemote != "") (
    hmLib.hm.dag.entryAfter [ "writeBoundary" ] ''
      pi_mem="$HOME/.pi/memory"
      if [ -d "$pi_mem/.git" ]; then
        cur=$(${pkgs.git}/bin/git -C "$pi_mem" remote get-url origin 2>/dev/null || true)
        if [ "$cur" != "${cfg.memoryRemote}" ]; then
          ${pkgs.git}/bin/git -C "$pi_mem" remote set-url origin "${cfg.memoryRemote}" 2>/dev/null \
            || ${pkgs.git}/bin/git -C "$pi_mem" remote add origin "${cfg.memoryRemote}"
          echo "pi memory remote set to ${cfg.memoryRemote}"
        fi
      fi
    ''
  );

  pi-qmd-deps = hmLib.hm.dag.entryAfter [ "writeBoundary" ] ''
    pkg_dir="$HOME/.config/dotfiles/packages/pi-packages/pi-qmd"
    lock_file="$pkg_dir/package-lock.json"
    stamp_file="$pkg_dir/.node-modules-lock-sha256"
    npm_bin="${pkgs.nodejs}/bin/npm"
    node_bin_dir="${pkgs.nodejs}/bin"
    sha_bin="${pkgs.coreutils}/bin/sha256sum"

    if [ -f "$lock_file" ] && [ -x "$npm_bin" ]; then
      current_sha="$($sha_bin "$lock_file" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
      saved_sha="$(cat "$stamp_file" 2>/dev/null || true)"
      needs_install=0

      if [ ! -d "$pkg_dir/node_modules/@tobilu/qmd" ]; then
        needs_install=1
      elif [ "$current_sha" != "$saved_sha" ]; then
        needs_install=1
      fi

      if [ -L "$pkg_dir/node_modules" ]; then
        rm -f "$pkg_dir/node_modules"
        needs_install=1
      fi

      if [ "$needs_install" -eq 1 ]; then
        echo "Installing pi-qmd npm deps..."
        (cd "$pkg_dir" && PATH="$node_bin_dir:$PATH" "$npm_bin" ci --workspaces=false --omit=dev) || echo "Warning: pi-qmd npm install failed."
        printf '%s\n' "$current_sha" > "$stamp_file"
      fi
    fi
  '';

  pi-extras = hmLib.hm.dag.entryAfter [ "writeBoundary" ] ''
    bun_bin="${pkgs.bun}/bin/bun"
    if [ -x "$bun_bin" ]; then
      bun_install_dir="''${BUN_INSTALL:-$HOME/.bun}"
      if [ ! -x "$bun_install_dir/bin/markit" ]; then
        echo "Installing markit..."
        "$bun_bin" install -g markit-ai \
          || echo "Warning: markit install failed."
      fi
      if [ ! -x "$bun_install_dir/bin/gitnexus" ]; then
        echo "Installing gitnexus..."
        "$bun_bin" install -g gitnexus \
          || echo "Warning: gitnexus install failed."
      fi
      if [ -f "$HOME/package.json" ] && ! grep -q '"license"' "$HOME/package.json"; then
        ${pkgs.jq}/bin/jq '. + {license: "UNLICENSED"}' "$HOME/package.json" > "$HOME/package.json.tmp" \
          && mv "$HOME/package.json.tmp" "$HOME/package.json"
      fi
    fi
  '';
}
