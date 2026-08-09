---
name: callstack-diff
description: This skill should be used when a user asks to "map the logic flow", "show the call flow", "visualize how this request branches", presents a prose or architecture flow such as `A → B → C` with branches, or asks to render or compare static JavaScript and TypeScript call-stack trees.
---

# Callstack Diff

Use `callstack-diff` (`csd`) to show a branching application flow as one
shared-prefix call tree. Run it directly on JS/TS source, or translate a prose
architecture flow into a minimal temporary TypeScript model first. The tool
reads source and Git history; it does not modify the repository.

## Choose the input

### Inspect existing JS/TS

Render the current tree for a function or method:

```bash
callstack-diff <entry> [paths...] --root <repository> --theme none
```

Compare a Git revision with the working tree:

```bash
callstack-diff diff <entry> [paths...] --root <repository> --from <ref> --theme none
```

`<entry>` may be a function name, `Class.method`, or `file.ts#name`. Pass
specific files or globs when the repository contains duplicate names.

### Model a prose or architecture flow

Create a temporary `.ts` file outside the repository when the flow exists only
as prose or arrows. Model only the stated structure:

- Represent each arrow as a function call.
- Keep the shared prefix in one entry chain instead of repeating it per branch.
- Represent branches with `if`, `else`, or `switch`.
- Use the domain terms from the prompt as function names.
- Add no imports, implementations, network calls, or invented behavior.

For example:

```ts
function routeGrievance() {
  receiveFromOmp();
}

function receiveFromOmp() {
  privateGrievanceEndpoint();
}

function privateGrievanceEndpoint() {
  deduplicateAndEnrich();
  retainRawReport();
  if (shouldEmitPostHogMetric()) sendPostHogMetric();
  if (isActionable()) createOrUpdateLinearIssue();
}
```

Render the model, then remove the temporary file:

```bash
callstack-diff routeGrievance /tmp/callstack-diff-flow.ts \
  --root /tmp --theme none
rm /tmp/callstack-diff-flow.ts
```

State that this output models the supplied architecture rather than claiming it
was extracted from production source.

## Interpret the result

- A shared prefix followed by distinct branch nodes exposes the logic without
  duplicating the whole flow in prose.
- A shallow, narrow tree is usually easier to understand and refactor.
- Added and removed nodes in `diff` output show how a source change reshaped the
  call path.
- Branch labels represent `if`, `else`, and `switch` structure unless
  `--no-branches` is set.
- Resolution is name-based, not type-aware. Dynamic dispatch, re-exports, and
  duplicate names can be ambiguous, so treat source-derived output as a
  readable approximation rather than a sound call graph.

Use `callstack-diff --help` for current flags and `callstack-diff skill` for the
skill bundled with the installed version. Finish by reporting the command,
entry, source or temporary model, and the structural change the tree reveals.
