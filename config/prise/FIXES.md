# Prise Fixes & Patches

## CWD URL Protocol Stripping (error.ChdirFailed)

**Issue:** When `kitty-shell-cwd://` or `file://` URLs are passed to spawn_pty's `cwd` parameter, prise fails with `error.ChdirFailed` because it passes the URL directly to `posix.chdir()`.

**Root Cause:** Session files (`~/.local/state/prise/sessions/*.json`) store URLs from OSC 7 escape sequences instead of plain paths. Example:

```json
"cwd": "kitty-shell-cwd://MacTraitor-Pro.local/Users/emiller/.config/dotfiles"
```

When restoring sessions, prise passes this URL to `posix.chdir()` which fails.

**Source Location:** `src/pty.zig` line 151:

```zig
if (cwd) |dir| {
    posix.chdir(dir) catch return error.ChdirFailed;
}
```

No URL parsing exists for spawn_pty cwd - only for OSC 7 in `vt_handler.zig`.

---

## Workaround (Without Patching Prise)

A shell-side workaround is implemented in `aliases.zsh`. On shell startup (outside prise), it sanitizes session files by stripping URL protocols:

```zsh
_prise_fix_session_cwds() {
  local sessions_dir="${HOME}/.local/state/prise/sessions"
  [[ -d "$sessions_dir" ]] || return 0

  for f in "$sessions_dir"/*.json(N); do
    if grep -q '"cwd": *"[a-z-]*://' "$f" 2>/dev/null; then
      sed -i.bak -E 's#"cwd": *"[a-z-]+://[^/]*(/.*)?"#"cwd": "\1"#g' "$f"
      rm -f "${f}.bak"
    fi
  done
}
```

This converts:

- `kitty-shell-cwd://hostname/path` → `/path`
- `file://hostname/path` → `/path`

---

## Upstream Fix (For Prise Patch)

**Fix Location:** `src/server.zig` in `handleSpawnPty` (around line 2083)

**Patch:**

```zig
// After: const parsed = parseSpawnPtyParams(params);
// Before: const cwd = parsed.cwd orelse posix.getenv("HOME");

var cwd = parsed.cwd orelse posix.getenv("HOME");

// Strip URL protocols from cwd (kitty-shell-cwd://, file://, etc.)
if (cwd) |path| {
    if (std.mem.indexOf(u8, path, "://")) |scheme_end| {
        const after_scheme = path[scheme_end + 3..];
        if (std.mem.indexOfScalar(u8, after_scheme, '/')) |idx| {
            cwd = after_scheme[idx..];
        } else {
            cwd = after_scheme;
        }
    }
}
```

**Files Affected:**

- `src/server.zig` - parseSpawnPtyParams (line 1943) and handleSpawnPty (line 2076)
- `src/pty.zig` - Process.spawn and childProcess (lines 45-176)

**Upstream PR:** TODO - submit to https://github.com/rockorager/prise
