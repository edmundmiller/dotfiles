---
name: code-search
description: Compares semantic, text, and structural search strategies. Use for intent-based discovery with sgrep or selecting a search/codemod approach, not for ordinary known-string lookups.
---

# Code search tool selection

Choose by what you know and what must match:

- Behavior without known identifiers: use `sgrep` for semantic discovery.
- Exact names, literals, regexes, or non-code text: use scoped `rg`.
- Syntax shape, codemods, or structural policy: use `ast-grep`. Load its skill
  for patterns, safe rewrites, rule tests, severity, and CI. Preview matches before
  rewriting; do not use text replacement for structural changes.

Use `rg` to shortlist files before a structural search when helpful. AST matching
distinguishes syntax nodes from incidental text in comments or strings.

## Semantic discovery with sgrep

Use Context.dev's `sgrep` when you know the behavior but not its identifiers.
Scope the search to a likely directory and inspect the returned source before
drawing conclusions. Rankings are approximate, not proof of behavior.

```bash
sgrep "retry failed requests with backoff" ./src -n 5 --json
```

When you already have useful patterns, rank only their matching passages. Run
both commands from the same directory so ripgrep paths resolve correctly.

```bash
rg --json -C 3 'retry|backoff' ./src \
  | sgrep "retry failed requests with backoff" --stdin --json
```

Keep `rg` for exact names, literals, and regexes. Keep `ast-grep` for syntax and
rewrites. If `sgrep` is unavailable, use scoped `rg` searches instead.

The first search downloads a 32–34 MB model and any required parsers. Source and
queries stay local, but the local index caches source passages. After assets
are cached, set `HF_HUB_OFFLINE=1` to prevent further downloads. `--no-cache`
disables index reads and writes, not model downloads. Do not bypass ignore
rules to include secrets in a search.

Upstream: https://github.com/context-dot-dev/sgrep. Other projects also use the
name `sgrep`; use the version packaged by these dotfiles.

## ripgrep examples

```bash
# Show line numbers for a literal-looking call; this also matches comments.
rg -n 'console\.log\(' -t js
# Search selected file types.
rg 'TODO|FIXME' -t py -t js
# Show surrounding lines.
rg -C 3 'error' -t log
# Return filenames only.
rg -l 'import.*React' -g '*.tsx'
```
