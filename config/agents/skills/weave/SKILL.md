---
name: weave
description: >
  Entity-level merge with weave. Use when setting up weave, previewing merges,
  reducing false Git conflicts, or validating merge-driver behavior.
license: MIT
metadata:
  version: "0.1.0"
---

# weave Skill

Use weave when Git line-conflicts are noisy but edits are logically independent.

## When to use

- "set up weave"
- "weave setup"
- "preview this merge"
- "why did git conflict on different functions"
- "test merge driver"

## Quick commands

```bash
# Configure current repo
weave setup

# Preview merge quality before merging
weave preview <branch>

# Execute merge (after setup, git uses weave driver)
git merge <branch>

# Optional: inspect CRDT state if using claims
weave status
```

## Validation checklist

```bash
# 1) binaries present
command -v weave weave-driver weave-mcp

# 2) repo config present
git config --local --get-regexp '^merge\.weave\.'

# 3) attributes include merge=weave
grep -n 'merge=weave' .gitattributes
```

Expected config:

```bash
merge.weave.name Entity-level semantic merge
merge.weave.driver weave-driver %O %A %B %L %P
```

## Fast regression test (temp repo)

```bash
tmpdir=$(mktemp -d) && cd "$tmpdir"
git init -q
git config user.name test && git config user.email test@example.com
cat > lib.ts <<'EOF'
export function a(x:number){ return x*2 }
export function b(s:string){ return s.length>0 }
EOF
git add lib.ts && git commit -qm base
weave setup >/dev/null

git checkout -qb left
perl -0pi -e 's/x\*2/x*3+1/' lib.ts
git commit -am left -q

git checkout -q @{-1}
git checkout -qb right
perl -0pi -e 's/s\.length>0/s.trim().length>0/' lib.ts
git commit -am right -q

git checkout -q left
git merge --no-ff right
```

Pass condition: merge completes and `git ls-files -u` is empty.

## Notes

- `weave setup` updates `.gitattributes` and local git merge-driver config.
- Keep driver command as `weave-driver ...` (PATH-resolved) to avoid stale nix-store paths.
- For AI tooling, `weave-mcp` is available; wire into your MCP client as needed.
