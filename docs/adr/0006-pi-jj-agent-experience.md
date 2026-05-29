# ADR 0006: Layer jj support around git-trained Pi agents

## Status

Proposed

## Date

2026-05-29

## Context

This repository already has a `modules.shell.jj` module with an agent-friendly jj
configuration: concise default log templates, useful aliases, colocated Git
settings, and a dedicated `modules/shell/jj/AGENTS.md` guide.

The next adoption target is Pi. Pi agents, extensions, and most model priors are
still heavily Git-shaped: they reach for `git status`, `git diff`, `git add`,
`git commit`, `git reset`, and `git push` even when a repository is managed by
Jujutsu. If jj is simply enabled and agents are told to remember a different
workflow, they will eventually bypass it.

This also intersects with `packages/pi-packages/pi-command-policy-bridge`, which
currently applies the existing `pi-permissions.jsonc` bash policy to tools that
embed shell commands. jj support should use the same deterministic policy layer
rather than relying on prompt instructions alone.

Packages reviewed for Pi + jj support:

| Package                                                                                                                                    | Useful parts                                                                                                                                                     | Adoption concern                                                                              |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| [`pi-jj-auto`](https://pi.dev/packages/pi-jj-auto)                                                                                         | Small baseline guard: blocks edits when the current jj revision already has described work, nudges `jj new` vs `jj desc`, and can auto-describe from the prompt. | Does not solve publish alignment or Git-trained command attempts.                             |
| [`pi-jj-git-align`](https://pi.dev/packages/pi-jj-git-align?name=jj)                                                                       | Colocated jj+Git status, `/jj-align-push`, and `jj_vcs` tool to align bookmark/Git HEAD/origin before claiming work is pushed. Keeps model context low.          | Mutating `jj_vcs.align_push` must be policy-gated like shell commands.                        |
| [`manojlds/pi-jj`](https://github.com/manojlds/pi-jj)                                                                                      | Full-featured onboarding, checkpoints, restore, stacked PR plan/publish/sync/close, `jj_stack_pr_flow`.                                                          | Overlaps with Pi rollback/checkpoints and needs careful policy gating for PR/publish actions. |
| [`atomdmac/pi-jj`](https://github.com/atomdmac/pi-jj)                                                                                      | jj workspace creation plus subagent delegation.                                                                                                                  | Overlaps with Herdr, `pi-side-agents`, and this repo's existing side-agent/worktree patterns. |
| [`manusajith/pi-jj-suite`](https://github.com/manusajith/pi-jj-suite) / [`pi-jj-dashboard`](https://github.com/manusajith/pi-jj-dashboard) | Larger shared registry, dashboard, work/inbox views, review/workspace/agent packages.                                                                            | Too much control-plane surface to enable globally before baseline jj behavior is proven.      |
| [`elianiva/dotfiles`](https://github.com/elianiva/dotfiles)                                                                                | Inspiration for jj/jjui/dotfiles organization.                                                                                                                   | Not a Pi-specific integration by itself.                                                      |

## Sources reviewed

Accessed on 2026-05-29. These sources are intentionally linked in the ADR so
future agents can re-check current behavior before implementing anything; Pi
packages are moving quickly.

| Source                                                                         | Notes                                                                                                                                                                                                                                              |
| ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`pi-jj-auto` on pi.dev](https://pi.dev/packages/pi-jj-auto)                   | Version reviewed: `0.1.6`, published 2026-05-05. Package declares both extension and skill resources. Its README describes edit guards, prompt-derived auto-descriptions, and config under `~/.pi/agent/pi-jj-auto.json` or `.pi/pi-jj-auto.json`. |
| [`pi-jj-git-align` on pi.dev](https://pi.dev/packages/pi-jj-git-align?name=jj) | Version reviewed: `0.1.3`, published 2026-05-28. Provides a compact status widget, `/jj-init`, `/jj-status`, `/jj-align-push`, and the `jj_vcs` tool for `status` / `align_push`.                                                                  |
| [`manojlds/pi-jj`](https://github.com/manojlds/pi-jj)                          | Full jj-first Pi package with onboarding, checkpoint restore, stacked PR commands, slash commands, and `jj_stack_pr_flow`.                                                                                                                         |
| [`atomdmac/pi-jj`](https://github.com/atomdmac/pi-jj)                          | Workspace/subagent package with `jj_workspace`, `/jj-workspace`, `/jj-attach`, `/jj-switch`, and lifecycle actions such as keep, squash, and delete.                                                                                               |
| [`manusajith/pi-jj-suite`](https://github.com/manusajith/pi-jj-suite)          | Meta-package that composes shared registry, workspaces, agents, dashboard, review, and suite package listing.                                                                                                                                      |
| [`manusajith/pi-jj-dashboard`](https://github.com/manusajith/pi-jj-dashboard)  | Dashboard/control-plane package backed by `pi-jj-shared`, with `/dashboard`, `/work`, `/inbox`, and `jj_dashboard_snapshot`.                                                                                                                       |
| [`elianiva/dotfiles`](https://github.com/elianiva/dotfiles)                    | Dotfiles repo with jj/jjui-related organization to inspect as design inspiration, not a Pi package source.                                                                                                                                         |

## Ideas to steal

| Source                            | Steal                                                                                                                                                                                                                                                                                                           | Do not steal yet                                                                                                                                            |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pi-jj-auto`                      | The small edit-before-revision-boundary guard. When a described dirty revision already exists, block edits with actionable choices: continue same task by describing, or start new task with `jj new`. Also steal the project-local/global JSON config split and low-friction debug env var pattern.            | Do not rely on auto-description as the only handoff mechanism; agents should still explicitly describe completed work.                                      |
| `pi-jj-git-align`                 | The narrow colocated publish contract: keep status human-visible, expose model-visible status only on request, require clean jj state before publish alignment, align bookmark/Git HEAD/origin around `@-`, then verify. Also steal the idea that publish alignment is a tool/command, not prose in the prompt. | Do not allow `align_push` as a silent default. It must be explicit and policy-gated.                                                                        |
| `manojlds/pi-jj`                  | The distinction between file restore and operation restore; checkpoint entries that capture revision, change id, and operation id; stacked PR planning before publishing; dry-run-first publish UX; retargeting stacked PR bases after ancestors merge.                                                         | Do not enable its full checkpoint/stacked-PR state machine globally until it is reconciled with Pi rollback, `hey`/policy rules, and existing PR workflows. |
| `atomdmac/pi-jj`                  | The pattern of jj workspaces as isolated agent work areas, plus post-run lifecycle choices: keep, squash, squash-and-delete, delete. This is useful design input for future Herdr/side-agent integration.                                                                                                       | Do not add another global side-agent/workspace control plane until it is clear how it composes with Herdr panes and existing side agents.                   |
| `pi-jj-suite` / `pi-jj-dashboard` | The shared registry concept: one canonical state layer for repos, work items, runs, reviews, health, and inbox/attention summaries. The dashboard snapshot tool is the right shape for model-visible summaries.                                                                                                 | Do not adopt the whole suite globally before the base jj workflow is boring; avoid duplicating dashboard state with Beads/Herdr/session tooling.            |
| `elianiva/dotfiles`               | Inspect jj/jjui layout and terminal workflow conventions for Nix/dotfiles organization, especially if this repo's jjui integration grows.                                                                                                                                                                       | Do not import their config wholesale; keep this repo's existing `modules.shell.jj` + `config/jj` split.                                                     |

## Decision

Adopt jj for Pi agents as a layered, Git-compatible experience instead of a
pure jj prompt-only migration.

### 1. Use colocated jj as the default agent model

Prefer `jj git init --colocate` for Git repositories that Pi agents will work in.
This keeps remotes, GitHub, and existing Git tooling available while making jj the
local change-management layer.

Agents may use Git for read-only inspection, especially where their priors are
strong:

- `git status`
- `git diff`
- `git log`
- `git show`
- `git remote -v`

Agents should not use Git's staging/commit/rewrite workflow inside jj repos:

- `git add`
- `git commit`
- `git reset --hard`
- `git checkout` for history movement
- `git rebase`
- `git merge`
- raw `git push` when jj/Git alignment matters

### 2. Install a small Pi jj baseline first

Use `pi-jj-auto` as the first broad Pi package once the module is re-enabled. It
matches the most common agent failure mode: continuing to edit a described dirty
revision that should have become a new change.

Keep this package as a guardrail, not as the complete jj UX.

### 3. Pilot publish alignment with `pi-jj-git-align`

Use `pi-jj-git-align` as the candidate package for publishing/backing up jj work
from colocated repositories because it has a narrow scope:

- human-visible jj status without dynamic prompt bloat;
- model-visible `jj_vcs status` when the agent needs explicit state;
- `/jj-align-push` / `jj_vcs align_push` for the common final alignment shape.

The expected final shape for direct-to-branch work is:

1. `@` is an empty working-copy change.
2. `@-` is the completed described change.
3. The target bookmark/branch points at `@-`.
4. Git HEAD and `origin/<branch>` are aligned with that completed change.

Publishing should remain explicit. Agents should not silently push just because a
task is complete.

### 4. Defer the larger jj control planes

Do not enable these globally yet:

- `manojlds/pi-jj`
- `atomdmac/pi-jj`
- `pi-jj-suite`
- `pi-jj-dashboard`

They are promising, but they each introduce additional state machines that
compete with existing repo patterns:

- Pi rollback/checkpoints;
- Herdr panes and side agents;
- current PR/worktree habits;
- future `pi-command-policy-bridge` enforcement.

They may be installed project-locally or tested in a dedicated pilot repo. The
next broad adoption point should be after the baseline jj policy and publish
alignment behavior are reliable.

### 5. Extend command policy for VCS-aware tools

`pi-command-policy-bridge` should become the enforcement point for extension
tools that perform VCS mutations, not just tools with a literal `command` string.
At minimum, policy coverage should include:

| Tool               | Safe/read action                                         | Mutating action                                         |
| ------------------ | -------------------------------------------------------- | ------------------------------------------------------- |
| `jj_vcs`           | `status` allowed                                         | `align_push` ask/guarded                                |
| `jj_stack_pr_flow` | `status`, `checkpoints`, `plan`, dry-run publish allowed | real `publish`, `sync`, `close`, `init` ask/guarded     |
| `jj_workspace`     | status/list-style actions allowed if added               | workspace create/squash/delete ask/guarded              |
| dashboard tools    | snapshots allowed                                        | complete/archive/open-in-shell ask if they mutate state |

The bridge should return concrete remediation guidance when blocking common Git
mutations in a jj repo, for example:

- `git add` → "jj snapshots automatically; use `jj diff` and continue."
- `git commit -m ...` → "use `jj describe -m ...` then `jj new --no-edit`."
- `git reset --hard` → "use `jj restore`, `jj abandon`, or ask before destructive cleanup."
- `git push` → "use `/jj-align-push <branch>` or `jj_vcs align_push` after status."

A static wildcard-only policy is not enough for this, because Git mutating
commands may still be legitimate in non-jj repositories. The jj policy should be
cwd-aware: detect whether the command is running inside a jj repository before
rewriting a Git-trained agent's behavior.

### 6. Recommended agent workflow

At task start:

```bash
jj status
jj log -r '@-::@' --limit 10
```

Before editing:

- If the current change is empty and undescribed, proceed.
- If the current change is described and dirty but belongs to the same task, use
  `jj describe -m "..."`.
- If the current change is described and belongs to prior work, use
  `jj new -m "..."`.

During work:

- Do not stage files.
- Use `jj diff` for the current change.
- Use `jj log` / `jj obslog` for local history.

At handoff:

```bash
jj describe -m "short task summary"
jj status
```

If asked to park/publish the completed change:

```bash
jj new --no-edit
# then use /jj-align-push <branch> or jj_vcs align_push after status
```

## Consequences

- Agents can keep using safe Git-shaped inspection commands without being trusted
  to remember all jj differences.
- The first global package addition is small and reversible.
- Publish alignment is handled by a purpose-built colocated jj+Git tool rather
  than ad hoc `git push` attempts.
- Larger jj workspace/dashboard/stacked-PR systems remain available for pilots
  without committing the whole Pi environment to them.
- `pi-command-policy-bridge` needs a VCS-aware extension point before mutating jj
  tools are broadly trusted.

## Follow-up work

1. Re-enable or test `modules.shell.jj` on the Pi host using the normal `hey re`
   deployment path.
2. Add `pi-jj-auto` to the Pi package list once package load behavior is verified.
3. Pilot `pi-jj-git-align` in this repo or a scratch colocated jj repo.
4. Extend `pi-command-policy-bridge` to classify known jj extension tools and
   cwd-aware Git mutations.
5. Add or update local agent guidance so blocked Git commands teach the jj
   equivalent instead of only denying the command.
