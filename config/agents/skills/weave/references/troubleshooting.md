<!-- Troubleshooting guide for common weave setup + merge-driver failures. -->

# weave Troubleshooting

Use this when weave is installed but merge behavior looks wrong.

## 1) `git merge` ignores weave (line conflicts still appear)

### Check

```bash
git config --local --get-regexp '^merge\.weave\.'
git check-attr merge -- path/to/file.ts
```

If `git check-attr` is not `merge: weave`, weave won't run.

### Fix

```bash
weave setup
grep -n 'merge=weave' .gitattributes
```

If file extension is custom, add pattern manually to `.gitattributes`.

## 2) Merge driver points at stale nix-store path

Symptom: old `/nix/store/.../weave-driver` path in local git config fails after rebuild/GC.

### Fix (preferred)

```bash
git config --local merge.weave.driver 'weave-driver %O %A %B %L %P'
```

Then verify:

```bash
git config --local --get merge.weave.driver
```

## 3) `weave-driver` not found

### Check

```bash
command -v weave weave-driver weave-mcp
```

### Fix

- Rebuild/apply profile so binaries are on PATH.
- Re-run `weave setup` in the repo.

## 4) `weave-mcp` exits with `ConnectionClosed("initialized request")`

Usually expected when launched standalone without an MCP client handshake.

### Fix

Run `weave-mcp` via MCP host/client integration, not as a plain terminal command.

## 5) weave runs, but conflict still remains

If both branches edited same entity/logic, semantic merge can still conflict.

### Triage

```bash
git ls-files -u
```

### Resolve

- Keep manual conflict resolution for true logical overlap.
- Use `weave preview <branch>` pre-merge to see likely conflict surface.

## Quick reset

If config drifted, reset quickly:

```bash
git config --local --unset-all merge.weave.driver || true
git config --local --unset-all merge.weave.name || true
weave setup
```
