# jut vs but (GitButler CLI) — Command Comparison

jut is a human and agentic framework around jj. It doesn't replace jj — you drop into raw `jj` anytime. Every jut command earns its place by adding structured JSON output (for agents), `--status-after` (for humans), or a genuinely opinionated UX improvement.

GitButler CLI (`but`) requires setup/teardown and can't coexist with raw git. jut has no such boundary — `jj` commands work alongside jut at all times.

## Commands jut has

| jut command | jj equivalent                | Why it exists                                                                                     |
| ----------- | ---------------------------- | ------------------------------------------------------------------------------------------------- |
| `status`    | `jj status`                  | JSON: workspace state w/ stacks, files, bookmarks. Human: colored + `--status-after` on mutations |
| `log`       | `jj log`                     | JSON: structured revision array w/ all metadata. Human: passthrough                               |
| `diff`      | `jj diff`                    | JSON: parsed files, additions/deletions stats. Human: passthrough                                 |
| `show`      | `jj show`                    | JSON: structured revision output. Human: `--verbose` adds inline diff                             |
| `commit`    | `jj commit`                  | JSON: returns new change_id. Human: describe + new in one step, colored output                    |
| `rub`       | `jj squash`/`jj restore`     | Unified "combine two things" verb (from GitButler). Positional args: `jut <source> <target>`      |
| `squash`    | `jj squash`                  | JSON: structured result. Simplified `--from`/`--into` positional args                             |
| `reword`    | `jj describe -r`             | Named verb for editing commit messages — clearer intent than `describe`                           |
| `discard`   | `jj restore`/`jj abandon`    | Unified verb — auto-detects file (restore) vs revision (abandon)                                  |
| `absorb`    | `jj absorb`                  | JSON: structured result. `--dry-run` support with plan output                                     |
| `push`      | `jj git push`                | JSON: push result. Hides `git` subcommand noise                                                   |
| `pull`      | `jj git fetch` + rebase      | Fetch + auto-rebase in one command. JSON: fetched bookmarks, rebase info                          |
| `pr`        | (none in jj)                 | Auto-detect bookmark, push, open GitHub PR via `gh`. Full workflow in one command                 |
| `branch`    | `jj bookmark set` + `jj new` | Create bookmark + new change in one step. Supports `--stack` for stacked branches                 |
| `undo`      | `jj undo`                    | JSON: undo confirmation. Colored output                                                           |
| `oplog`     | `jj operation log`           | JSON: structured op list. `--restore` to restore a specific operation                             |
| `restore`   | `jj restore`                 | JSON: structured result                                                                           |
| `stack`     | (none in jj)                 | Visualize commit stacks with status indicators — no jj equivalent                                 |

## jj commands jut intentionally does NOT wrap

Drop into `jj` directly for these. No value in wrapping them.

| jj command          | Why jut skips it                                                                  |
| ------------------- | --------------------------------------------------------------------------------- |
| `jj split`          | Interactive — requires editor/TUI. jut can't add value over the native experience |
| `jj edit`           | One-liner (`jj edit <rev>`). No structured output needed                          |
| `jj new`            | Already covered by `jut commit` and `jut branch`. Raw `jj new` for advanced cases |
| `jj rebase`         | Complex revset args — wrapping adds nothing, would lose flexibility               |
| `jj resolve`        | Interactive merge tool. jut can't improve on `jj resolve`                         |
| `jj diffedit`       | Interactive editor. Same reason as split/resolve                                  |
| `jj next`/`jj prev` | Trivial one-liners. No JSON use case                                              |
| `jj duplicate`      | Rare operation. No agent use case                                                 |
| `jj bisect`         | Interactive workflow. No wrapping value                                           |
| `jj bookmark` (raw) | `jut branch` covers the common case. Raw `jj bookmark` for advanced management    |
| `jj config`         | Config management — not a repo operation                                          |
| `jj git` (raw)      | `jut push`/`jut pull` cover the common cases. Raw for advanced git interop        |
| `jj evolog`         | Debugging tool. No structured output needed                                       |
| `jj fix`            | Project-specific formatter integration. Pass through to jj                        |
| `jj parallelize`    | Advanced history rewriting. Rare, complex revset args                             |
| `jj sparse`         | Workspace management. Not a common workflow                                       |
| `jj sign`           | Signing. Rare, no agent use case                                                  |
| `jj abandon`        | Covered by `jut discard`. Raw for bulk abandon with revsets                       |
| `jj describe`       | Covered by `jut reword`. Raw for advanced metadata edits                          |
| `jj restore` (raw)  | Covered by `jut discard` (files) and `jut restore`. Raw for complex path specs    |

## but commands jut maps differently

| but command            | jut equivalent | Notes                                                                        |
| ---------------------- | -------------- | ---------------------------------------------------------------------------- |
| `but status`           | `jut status`   | Same concept, different VCS                                                  |
| `but commit`           | `jut commit`   | jut doesn't need staging — jj's working copy model                           |
| `but stage`            | (none)         | jj has no staging area — working copy IS the stage                           |
| `but branch`           | `jut branch`   | Similar. jut uses jj bookmarks underneath                                    |
| `but merge`            | (none)         | Use `jj rebase` directly — jj's model is different from git merge            |
| `but rub`              | `jut rub`      | Same verb, inspired by GitButler                                             |
| `but absorb`           | `jut absorb`   | Same concept                                                                 |
| `but push`             | `jut push`     | Same                                                                         |
| `but pull`             | `jut pull`     | Same — fetch + update                                                        |
| `but pr`               | `jut pr`       | Same                                                                         |
| `but reword`           | `jut reword`   | Same                                                                         |
| `but squash`           | `jut squash`   | Same                                                                         |
| `but discard`          | `jut discard`  | Same — unified discard verb                                                  |
| `but undo`             | `jut undo`     | Same                                                                         |
| `but oplog`            | `jut oplog`    | Same                                                                         |
| `but resolve`          | (none)         | Use `jj resolve` directly                                                    |
| `but uncommit`         | (none)         | Use `jj squash --from` or `jj restore` — jj's model handles this differently |
| `but amend`            | `jut rub`      | `rub` is the universal "combine" verb                                        |
| `but move`             | (none)         | Use `jj rebase` directly                                                     |
| `but mark`/`unmark`    | (none)         | GitButler-specific auto-stage rules. No jj equivalent                        |
| `but setup`/`teardown` | (none)         | jut has no setup/teardown — jj repos just work                               |
| `but gui`              | (none)         | No GUI component                                                             |
