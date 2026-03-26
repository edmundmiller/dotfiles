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

```bash
# Use the full path
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .
# Or let hey handle it (it builds via nix as fallback)
hey re
```

## General Debugging Steps

1. **Read the error message** — Nix errors are verbose but usually point to the exact file and line.
2. **Check `git status`** — uncommitted changes can cause eval failures if a new file is referenced.
3. **Try `nix flake check`** — catches most issues without doing a full rebuild.
4. **Roll back** — `hey rollback` restores the previous generation while you debug.
