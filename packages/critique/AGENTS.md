# Critique

Fetch `remorses/critique` upstream and carry the former fork delta as ordered
plain patches. The fully patched tree owns the checked-in package-lock and
`npmDepsHash`; the fork is not a build input. Binary/rename changes require
Git-aware patch application rather than ordinary `patch` semantics.

Preserve Pi ACP review support, direct JSONL fallback for sessions ACP cannot
load, and `--no-ext-diff` for parseable Git output. Runtime needs `pi-acp` in
the user environment.

The wrapper runs `src/cli.tsx` on Bun with production dependencies. `public/`
font assets are runtime inputs for PDF/image generation, not disposable build
artifacts. Pin/patch updates follow `nix-package-patching`.

Build the package for pin, lock, patch, or wrapper changes, then run `hey check`
on `packages/critique`. Include a PDF/image smoke check when fonts or the
production dependency closure changes.
