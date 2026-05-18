---
name: code-search
description: Use when searching code, refactoring, running codemods, or choosing between search tools. Provides guidance on ast-grep vs ripgrep selection and usage patterns.
---

# Code Search & Refactoring Tools

## ast-grep vs ripgrep

### When to Use ast-grep

**Use `ast-grep` when structure matters.** It parses code and matches AST nodes, so results ignore comments/strings, understand syntax, and can **safely rewrite** code.

**Best for:**

- Refactors/codemods: rename APIs, change import forms, rewrite call sites or variable kinds
- Policy checks: enforce patterns across a repo (`scan` with rules + `test`)
- Editor/automation: LSP mode; `--json` output for tooling
- Any operation where you'll **apply changes** to code

### When to Use ripgrep

**Use `ripgrep` when text is enough.** It's the fastest way to grep literals/regex across files.

**Best for:**

- Recon: find strings, TODOs, log lines, config values, or non‑code assets
- Pre-filter: narrow candidate files before a precise pass
- Quick searches where you just need to **find text**

## Rule of Thumb

- Need correctness over speed, or you'll **apply changes** → start with `ast-grep`
- Need raw speed or you're just **hunting text** → start with `rg`
- Often combine: `rg` to shortlist files, then `ast-grep` to match/modify with precision

## Usage Examples

### ast-grep Examples

**Find structured code** (ignores comments/strings):

```bash
ast-grep run -l TypeScript -p 'import $X from "$P"'
```

**Codemod** (only real `var` declarations become `let`):

```bash
ast-grep run -l JavaScript -p 'var $A = $B' -r 'let $A = $B' -U
```

**Find function calls with specific patterns:**

```bash
ast-grep run -l Python -p 'logger.$METHOD($$$ARGS)'
```

**Replace with transformation:**

```bash
ast-grep run -l TypeScript \
  -p 'useQuery($ARGS)' \
  -r 'useSuspenseQuery($ARGS)' \
  -U
```

### ripgrep Examples

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

### Combined Approach

**Speed + Precision:** Use `rg` to find candidates, then `ast-grep` for precise operations:

```bash
rg -l -t ts 'useQuery\(' | xargs ast-grep run -l TypeScript \
  -p 'useQuery($A)' \
  -r 'useSuspenseQuery($A)' \
  -U
```

## Mental Model

| Aspect              | ast-grep                   | ripgrep                 |
| ------------------- | -------------------------- | ----------------------- |
| **Unit of match**   | AST node                   | Line                    |
| **False positives** | Low (understands syntax)   | Depends on regex        |
| **Rewrites**        | First-class, safe          | Requires sed/awk, risky |
| **Speed**           | Slower (parses code)       | Fastest (text only)     |
| **Use case**        | Structural search/refactor | Text search/grep        |

## Quick Decision Tree

```
Need to modify code?
├─ Yes → ast-grep (safe, structural rewrites)
└─ No
   ├─ Searching code structure? → ast-grep (accurate)
   └─ Just finding text? → ripgrep (fastest)
```

## Common Patterns

### Finding all function definitions

```bash
# ast-grep (language-aware)
ast-grep run -l Python -p 'def $NAME($$$PARAMS): $$$BODY'

# ripgrep (text-based, faster but less precise)
rg '^def \w+\(' -t py
```

### Refactoring API calls

```bash
# ast-grep: Safe, precise
ast-grep run -l JavaScript \
  -p 'axios.get($URL)' \
  -r 'fetch($URL)' \
  -U

# ripgrep: Don't use for rewrites (will match in comments/strings)
```

### Finding TODOs

```bash
# ripgrep: Perfect for this
rg 'TODO:|FIXME:' --color=always

# ast-grep: Overkill for text search
```
