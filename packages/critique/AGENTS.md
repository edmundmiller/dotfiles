# critique

Nix package for the **Pi-enabled fork** of [critique](https://github.com/remorses/critique).

**Fork tracked here:** [edmundmiller/critique](https://github.com/edmundmiller/critique)
**Upstream:** [remorses/critique](https://github.com/remorses/critique)

## What is different about this fork

This package intentionally follows the fork, not upstream `main`.

1. **Single-package layout instead of the upstream workspace**
   - Upstream keeps the CLI in `cli/` and also carries extra workspace packages.
   - The fork flattens the repo into one root package, which makes Nix packaging simpler and keeps this derivation focused on the CLI.

2. **Pi review-agent support**
   - The fork adds `critique review --agent pi`.
   - Internally, critique talks to `pi-acp` so review generation can use Pi alongside the existing OpenCode/Claude paths.

3. **Pi session context support**
   - The fork can discover Pi sessions from `~/.pi/agent/sessions/...`.
   - If ACP session listing/loading is unavailable, it falls back to reading Pi JSONL session files directly so `--session` context still works.

4. **Dotfiles-specific git compatibility fixes**
   - The fork includes diff-command hardening such as `--no-ext-diff`, which matters in this repo because global git diff tooling can otherwise interfere with critique's parsing.
   - ACP stderr is also suppressed/drained so review mode stays cleaner in terminal use.

5. **Docs lag the code**
   - The fork README still mostly reflects upstream and does **not** fully document Pi support yet.
   - When behavior seems ambiguous, trust `src/cli.tsx` and `src/review/acp-client.ts` over the README.

## Packaging notes

- critique still **runs on Bun**, so the wrapper launches the checked-in `src/cli.tsx` with `${bun}/bin/bun`.
- Dependencies are installed with `buildNpmPackage`, then shipped alongside the source tree so Bun can resolve runtime imports.
- The wrapper prefixes Bun onto `PATH`, but Pi review mode still expects `pi-acp` to be available in the user environment.

## Updating

1. Inspect the fork diff against upstream if you are deciding whether to keep tracking the fork.
2. Bump `rev` and `hash` in `default.nix`.
3. Regenerate `package-lock.json` from the fork root:
   ```bash
   npm install --package-lock-only --ignore-scripts
   ```
4. Recompute `npmDepsHash`.
5. Smoke-test with:
   ```bash
   nix build .#critique
   ./result/bin/critique --help
   ```
