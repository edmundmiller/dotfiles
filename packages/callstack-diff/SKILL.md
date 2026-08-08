---
name: callstack-diff
description: Use callstack-diff (csd) to render or compare static JavaScript and TypeScript call-stack trees when planning or reviewing refactors, investigating call depth and branching, or checking how a Git change reshaped a call path.
---

# Callstack Diff

Use `callstack-diff` to inspect a readable approximation of a JS/TS call graph.
`csd` is an equivalent short command. The tool reads source and Git history; it
does not modify the repository.

## Choose a command

1. Render the current tree for a function or method:

   ```bash
   callstack-diff <entry> [paths...] --root <repository> --theme none
   ```

2. Compare a Git revision with the working tree:

   ```bash
   callstack-diff diff <entry> [paths...] --root <repository> --from <ref> --theme none
   ```

`<entry>` may be a function name, `Class.method`, or `file.ts#name`. Pass
specific files or globs when the repository contains duplicate names. Use
`callstack-diff --help` for current flags and `callstack-diff skill` for the
skill bundled with the installed version.

## Interpret the result

- A shallow, narrow tree is usually easier to understand and refactor.
- Added and removed nodes in `diff` output show how the call path changed.
- Branch labels represent `if`, `else`, and `switch` structure unless
  `--no-branches` is set.
- Resolution is name-based, not type-aware. Dynamic dispatch, re-exports, and
  duplicate names can be ambiguous, so treat the output as a guide rather than
  a sound call graph.

Finish by reporting the command, entry, root or refs, and the structural change
the tree reveals.
