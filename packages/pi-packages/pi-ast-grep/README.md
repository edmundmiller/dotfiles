# pi-ast-grep

Pi package that makes ast-grep a first-class tool in agent sessions.

## Why

`ast-grep outline` gives agents a fast local map of code structure: between `rg` and a full LSP, syntax-aware, no index to maintain, and extensible through declarative extraction rules.

This package pins `@ast-grep/cli@0.44.0` so Pi gets the new `outline` command even while Homebrew may still be on `ast-grep 0.43.x`.

## Tools

- `ast_grep_outline` — code structure map for files/directories.
- `ast_grep_search` — structural search with `ast-grep run`.
- `ast_grep_rewrite` — structural rewrite with `ast-grep run --rewrite`; defaults to preview diff, `mode: "apply"` mutates files with `--update-all`.
- `ast_grep_scan` — run project/rule/inline-rule scans; `mode: "apply"` applies rule fixes with `--update-all`.
- `ast_grep_doctor` — verify the binary and outline support.

## Install in Pi

Install the public repo package on each machine:

```bash
pi install git:github.com/joelhooks/pi-ast-grep@main
```

Pi clones the package and runs `npm install`, which installs the pinned `@ast-grep/cli@0.44.0` binary under the package. Then restart Pi or run `/reload` in an interactive session.

## Development

```bash
npm install
npm run check
npm run smoke
```

## Notes

- The tools call ast-grep with argv arrays, not shell strings.
- Output is truncated to 2,000 lines or 50 KiB; full output is saved to a temp file when truncated.
- Rewrite/apply flows are intentionally sharp: preview broad codemods, use `mode: "apply"` when the pattern/rules/paths/globs are narrow enough to trust, then inspect the returned diff.
