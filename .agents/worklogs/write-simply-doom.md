# Worklog: write-simply-doom

Status: blocked

## Objective

Prepare deterministic Vale 3.18 and vale-ls 0.5 editor prerequisites, a writable global Vale configuration, and sensible native prose scopes. Stop when focused checks pass and the remaining release and Doom-repository blockers are exact.

## Decisions

- Keep lsp-mode plus Flycheck as the single diagnostics path. The active Doom config does not use Eglot or Flymake.
- Scope editor prose checks to Markdown, native MDX, Org, and text. Exclude LaTeX because Vale does not parse it natively and a Markdown mapping would produce noisy diagnostics on TeX markup.
- Do not add the documented `v1.1.0` package URL until GitHub serves that release asset.
- Keep Doom Lisp changes out of this repository because `edmundmiller/.doom.d` owns `config.el` and `packages.el`.

## Evidence

- `gh api repos/edmundmiller/write-simply/releases/tags/v1.1.0`: HTTP 404.
- `git ls-remote --tags https://github.com/edmundmiller/write-simply.git`: no tags.
- Official Vale docs confirm global config paths, package pinning, native MDX and Org support, and vale-ls debounce/save settings.
- Official release archives matched their published SHA-256 digests and reported `vale version 3.18.0` and `vale-ls 0.5.0`.
- A live Vale 3.18 check produced the expected spelling diagnostics in native `.mdx` and `.org` fixtures while ignoring MDX attributes and inline code.
- `python3 -m unittest tests.test_emacs_vale -v`: 3 tests passed.
- `python3 tests/test_package_policy.py`: 8 tests passed.
- The full Python suite ran 180 tests after excluding `test_shared_checker_skips_emscripten_python`, which recursively invokes the full suite. The same recursion occurs on `origin/main`. Its 6 failures, 48 errors, and 13 skips match the target branch and come from missing `nix`, `omp`, `jj`, and `secret-tool`; the three new tests pass.
- The full Bun suite reported 53 passes, 9 failures, and 4 setup errors. The result is identical on `origin/main`; failures require the unavailable Herdr runtime and `vitest-evals` dependency.
- `python3 bin/agent-quality audit-tests tests`: passed.

## Reviews

No cross-model review requested.

## Feedback

The repository workflow assumes Nix is installed at `/run/current-system/sw/bin/nix`; the orb has no Nix, so `hey agent-start`, Nix evaluation, and package builds cannot run here.

## Remaining work

- After `v1.1.0/WriteSimply.zip` is published, add its exact URL and run `vale sync`.
- Add the lsp-mode client and prose hooks in `edmundmiller/.doom.d`, the repository that owns Doom configuration.
- Run Nix evaluation and package builds on a Nix host; this orb does not include Nix.

## Commits

- `feat(emacs): prepare Vale prose diagnostics` (single squashed commit)
