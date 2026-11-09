# Runbook: Rebuild Failure

## Symptoms

- `hey re` (or `darwin-rebuild switch --flake .`) exits non-zero
- `nixos-rebuild switch` fails on the NUC

## Common Causes & Fixes

### 1. Lock file drift (skills child flake)

**Symptom:** Error mentioning `skills-catalog` or mismatched input hashes.

```bash
# Fix: sync the parent lock with the child flake
cd ~/.config/dotfiles
nix flake update skills-catalog
hey re
```

### 2. Broken flake input

**Symptom:** `error: cannot fetch` or hash mismatch on a flake input.

```bash
# Update the broken input (e.g., nixpkgs)
nix flake update nixpkgs
# Or update all inputs
nix flake update
hey re
```

### 3. Disk space exhaustion

**Symptom:** `No space left on device` during build.

```bash
# Garbage collect old generations
nix-collect-garbage -d
# On NUC
ssh nuc "sudo nix-collect-garbage -d"
```

### 4. Evaluation error (Nix syntax)

**Symptom:** `error: syntax error, unexpected ...` or `attribute missing`.

```bash
# Check which file is broken
nix flake check 2>&1 | head -20
# Run deadnix/statix for quick lint
nix develop -c deadnix .
nix develop -c statix check .
```

### 5. Darwin-rebuild not found

**Symptom:** `darwin-rebuild: command not found` after a macOS update.

`hey re` builds `.#darwinConfigurations.<host>.system` once, as you (warm
user eval cache). For `switch` and `check` it then runs
`sudo darwin-rebuild --flake <tmp>#hey --impure <action>` on a generated
flake whose only output is that prebuilt system, so root does a trivial
evaluation instead of re-evaluating the whole config with a cold cache.
`build` needs no root. When `/run/current-system/sw/bin/darwin-rebuild` is
missing, the freshly built system's `darwin-rebuild` is used. Other actions
and profile flags (`--rollback`, `-p`, `-G`, `--list-generations`,
`--dry-run`) go straight to upstream `darwin-rebuild --flake <checkout>`.

### 6. Rebuild seems stuck or very slow

**Symptom:** `hey re` prints `waiting for the system-evaluation lock held by
pid ...`, or warns about memory pressure / swap.

`hey re` and `hey test` serialize full-system evaluations per user, because
concurrent evaluations (for example from many agent sessions) slow each other
down 10-20x. The message names the holder's pid, task and checkout; let it
finish or stop it. A lock left by a killed process is reclaimed
automatically. The lock lives at `~/.cache/hey/system-eval.lock`.

The memory warning is advisory: with swap nearly full, close other Nix
evaluations or agent sessions before rebuilding.

## General Debugging Steps

1. **Read the error message** — Nix errors are verbose but usually point to the exact file and line.
2. **Check `git status`** — uncommitted changes can cause eval failures if a new file is referenced.
3. **Try `nix flake check`** — catches most issues without doing a full rebuild.
4. **Roll back** — `hey rollback` restores the previous generation while you debug.
