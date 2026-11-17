---
purpose: Record deterministic Oxlint policy and explicitly opted-in semantic review.
applies_to: JavaScript and TypeScript lint, Jev questions and diff review.
entrypoint: Ordinary hooks and hey check use AST rules only. Jev is opt-in.
verification: python3 -m unittest tests.test_oxlint_jev tests.test_package_policy
update_when: Source pins, rules, disclosure scope or packaging change.
---

# Oxlint

Ordinary lint, editor checks, pre-commit and `hey check` do not send code to a
model, require model credentials or run paid checks. The default config registers
only AST plugins. Jev and diff review are separate, explicitly invoked commands.
Supplying credentials does not enable them in ordinary checks.

## Deterministic lint

The ordinary hook retains its original Oxlint 1.78.0, source pin, 15 error-level
rules and suppression file. Edmund approved staged activation. A second ordinary
AST hook enables the two zero-conflict core additions, their native accumulating-spread
companion, 12 compatible Effect rules and seven Fowler advisories.
Only the newly vendored build is excluded from source lint and formatting.

`packages/anti-slop/rules.json` preserves the original policy for both scans.
The additive scan also loads the original rule source with its matching 1.86.0
CLI/API pair, so the existing suppression counts remain valid. It does not bypass
suppression validation. The original 1.78.0 gate still runs independently.

Conflicting core rules and the two Effect rules `no-manual-tag-comparison` and
`prefer-effect-match` remain in the explicit full proposal. This is approved
staging, not a permanent exemption or full acceptance.

```sh
nix run .#anti-slop-proposal -- path/to/file.ts
```

`packages/anti-slop-proposal/oxlint.json` owns this explicit proposal. It enables core rules at
error, Fowler AST recommendations at warn and keeps `message-chains` off. Effect
AST rules apply only to `packages/callstack-diff/**`, which uses Effect
4.0.0-beta.105. The package's existing Effect tsgo lint remains separate and
unchanged. All former core error severities remain errors in the proposal, including the renamed,
broader `no-conditional-spread` rule.

The source is [K-Mistele/anti-slop](https://github.com/K-Mistele/anti-slop) at
`b7c1619b4d51b4815e89ba3700a975a6ec54b8c3`, supplied by the immutable flake
`anti-slop-incoming` input. Both proposal Oxlint and `@oxlint/plugins` are pinned to **1.86.0**, the pair tested
upstream. Nix packages use Node 22 with TypeScript stripping. Source and license
lineage is recorded in `packages/anti-slop-proposal/UPSTREAM.md`. The proposal
currently fails on incoming findings and suppression compatibility checks. It is
not wired into ordinary hooks or `hey check`; only `anti-slop-additions` is.
No suppressions were regenerated.

## Optional local questions

```sh
nix run .#oxlint-jev
nix run .#oxlint-jev -- --all path/to/file.ts
```

The default command reviews staged, unstaged and non-ignored untracked JS/TS
files relative to the current directory. Deleted files and unchanged files are
omitted. Within those files the three local call/function questions only select
nodes overlapping changed lines. Selected nodes are sent as snippets, including
unchanged lines within that function or call. This is not changed-lines-only
disclosure. Run from the repository root for the configured agent-directory
ignores and package-scoped overrides to apply.

The pinned fork has a known changed-line parser limitation for tracked paths
containing spaces. Git's `+++` header can leave a trailing tab in its map key,
so the lookup can silently skip semantic questions for that file. A successful
exit does not prove complete review of space-containing paths. The fork and
questions remain pinned; this integration does not broaden scope to work around it.

`--all` reviews all selected files and nodes. Arguments after `--` are passed to
Oxlint, except the runner's `--all`, `--ext` and `--oxlint` options. Explicit file
arguments do not override the changed-file filter without `--all`.

The three local `rules.json` questions retain their targets, thresholds and error
severities. They migrate from `jev/ask` to `jev/<id>` through `createJevPlugin`:

| Question              | Target   | Cutoff |
| --------------------- | -------- | ------ |
| no-pii-in-logs        | call     | 0.8    |
| no-secrets-in-logs    | call     | 0.8    |
| name-matches-behavior | function | 0.6    |

Each yes answer at or above the cutoff reports. The local plugin retains
`ci: "skip"`, which controls errors, not whether requests happen. A key permits
requests even with `CI=1`. Missing credentials or API failures warn and skip the
local questions. No CI workflow invokes this command.

## Optional whole-file semantic presets

```sh
nix run .#oxlint-jev -- --presets
```

This second opt-in adds the 12 upstream Fowler questions at warn, the 10 Effect
source questions at error only in `packages/callstack-diff/**`, and
`test-cannot-fail` at error for test files. Source questions are off for tests.
It retains the local questions too. Upstream preset `ci: "fail"` remains intact,
but there is no paid CI gate or workflow wiring.

All Effect questions and eight Fowler questions target **whole files**. The four
other Fowler questions target functions and filter changed overlaps. Unchanged
files are excluded, but file-targeted questions can transmit unchanged functions
in a changed file. `JEV_CHANGED_ONLY=1` does not redact file-targeted questions.
Snippet limits can truncate long files. Review this boundary before using the
command. Neither the fork nor preset questions are modified to imply a narrower
boundary.

`JEV_CHANGED_BASE` changes the node filter's base, not the runner's HEAD-based
changed-file selection. It is not a branch-wide selection flag. The fork can
fall back to checking every line if it cannot resolve a diff base; heed its
warning rather than relying on a failed base for disclosure control.

## Optional change-set review

```sh
nix shell .#oxlint-plugin-jev --command anti-slop-diff --base origin/main --working --json
```

Diff review judges shotgun surgery, divergent change, duplicated code and scope
creep. It sends diff hunks including context, changed-file summaries and commit
history, not just added lines or edited functions. With no backend configured it
warns and exits successfully. Credentials can select a backend automatically, so
invoking this command is an explicit request to use that configured backend.
`--backend command --command '<local program>'` supports offline testing. Never
wire it into an ordinary hook, editor command or CI gate.

## Credentials and provenance

No new credential is needed for installation or deterministic validation. For
explicit semantic use, the fork accepts `TYPESAFE_API_KEY` or
`TYPESAFE_AI_API_KEY`, Factory credentials, or AI Gateway credentials. Never put
their values in Nix, Git or command arguments. `.envrc.local` is gitignored;
`op run -- oxlint-jev` and `op://Vault/TypeSafe/credential` are existing local
secret routes. `TYPESAFE_API_KEY_FILE` remains supported by the Jev wrapper.

`packages/oxlint-plugin-jev/vendor/oxlint-plugin-jev` is the unmodified MIT build
bundled by the pinned anti-slop source, from K-Mistele/oxlint-plugin-jev at
`fd3e4b1ad3b8fa7c0d08cdc92633e33c7e662f9e`. Its README, license and `UPSTREAM.md`
travel with it. Both semantic CLI/API pins also equal 1.86.0. Refresh the fork
from its source build, not by editing `dist`; use `npm install --install-links
--ignore-scripts` to refresh its lock. Preserve local questions during updates.
