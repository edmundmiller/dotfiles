---
name: code-search
description: Use when searching code by unknown means or choosing between text and structural search tools. Owns ast-grep vs ripgrep selection and text-search guidance.
---

# Code Search Tool Selection

Use this skill to choose the search or refactoring tool. After selecting ast-grep, load `ast-grep`; that skill owns pattern syntax, rewrites, repository rule setup, tests, severity, and CI.

## ast-grep vs ripgrep

### When to Use ast-grep

**Use `ast-grep` when structure matters.** It parses code and matches AST nodes, so results ignore comments/strings, understand syntax, and scope rewrites to matched code.

**Best for:**

- Refactors/codemods: rename APIs, change import forms, rewrite call sites or variable kinds
- Policy checks: enforce patterns across a repo (`scan` with rules + `test`)
- Editor diagnostics and automation: LSP mode; structured JSON output
- Syntax-structured code changes after previewing the matches

### When to Use ripgrep

**Use `ripgrep` when text is enough.** It's the fastest way to grep literals/regex across files.

**Best for:**

- Recon: find strings, TODOs, log lines, config values, or non‑code assets
- Pre-filter: narrow candidate files before a precise pass
- Quick searches where you just need to **find text**

## Rule of Thumb

- Need a syntax-structured code change → start with `ast-grep`
- Need raw speed or you're just **hunting text** → start with `rg`
- Often combine: `rg` to shortlist files, then `ast-grep` to match/modify with precision

## ripgrep examples

**Quick textual hunt:**

```bash
rg -n 'console\.log\(' -t js
```

**Find in specific file types:**

```bash
rg 'TODO|FIXME' -t py -t js
```

**Context around matches:**

```bash
rg -C 3 'error' -t log
```

**List files with matches:**

```bash
rg -l 'import.*React' -t tsx
```

## Mental Model

| Aspect              | ast-grep                   | ripgrep                 |
| ------------------- | -------------------------- | ----------------------- |
| **Unit of match**   | AST node                   | Line                    |
| **False positives** | Low (understands syntax)   | Depends on regex        |
| **Rewrites**        | Syntax-scoped              | Text replacement, risky |
| **Speed**           | Slower (parses code)       | Fastest (text only)     |
| **Use case**        | Structural search/refactor | Text search/grep        |

## Quick Decision Tree

```
Need to change syntax-structured code?
├─ Yes → ast-grep
└─ No
   ├─ Searching code structure? → ast-grep
   └─ Just finding text? → ripgrep
```

## Selection examples

- Find function definitions by syntax → use ast-grep, then load `ast-grep`.
- Refactor API calls → use ast-grep; do not use text replacement.
- Find TODOs, log messages, or configuration values → use ripgrep.
