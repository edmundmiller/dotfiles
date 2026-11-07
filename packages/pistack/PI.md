# Pistack

Pistack packages Cursor's pinned pstack skills for Pi. It is not a Cursor
plugin and does not install a delegation backend. This contract overrides host-specific
instructions in every bundled skill, agent, playbook, and script description.
Read the upstream workflow for its reasoning and required evidence, then apply
these mappings to its execution. Bundled agent files are reference briefs,
not registered Pi agents. Read them as instructions only where useful, never
as a reason to launch another agent runtime or search Cursor's plugin directory.

## Authority

The user's authorization, repository rules, and Pi's permissions still apply.
Pstack does not authorize publishing, pushing, merging, deploying, messaging,
ticket updates, secret access, or deletion. Do not edit installed skills, host
configuration, or extension code to repair missing capabilities mid-task.

## Skills and tools

- `/name`, `/pstack:name`, and bold skill names refer to skills, not literal
  Cursor commands. In Pi use `/skill:name`, or read the bundled
  `skills/<name>/SKILL.md` relative to this file. Shared `tdd`, `teach`, and
  `unslop` are not registered twice; use their advertised shared copies.
  Their upstream files remain here for relative links.
- Use Pi's advertised `read`, `bash`, `edit`, and `write` tools. Use `rg` through
  `bash` for search. Resolve `AskQuestion`, todos, browser control, MCP, and
  external skills through installed capabilities. Without an appropriate tool,
  ask in chat or keep a concise checklist. Do not invent tool names.
- Cursor Automations, Bugbot, cloud agents, durable schedulers, artifact hosts,
  and automatic worktree management are not supplied by this package. Skip
  unavailable steps with an explicit limitation. Foreground sessions are not
  durable jobs. Do not claim Cursor feature parity.

## Skill storage

For both discovery and generated output, translate Cursor skill paths as follows.
This applies to the entire skill directory, including scripts and feature maps.

| Cursor path         | Pi path               |
| ------------------- | --------------------- |
| `.cursor/skills/`   | `.pi/skills/`         |
| `~/.cursor/skills/` | `~/.pi/agent/skills/` |

Search `.agents/skills/` and `~/.agents/skills/` for existing skills too. Follow
repository routing before choosing an output path. In this dotfiles repository,
shared skills belong in `skills/catalog/` and project-only skills belong in
`.agents/skills/`. Edit those sources, not deployed Nix-managed links. Never
write generated skills into the immutable pistack package or `.cursor/skills/`.
Use Pi's `/reload` after creating a skill, then confirm it is discovered.

## Delegation and models

Run supported work in the current Pi session. Upstream `Task`, `subagent_type`,
background/resume instructions, named agents, and model-role defaults do not
create capabilities in Pi. Do not install or enable a backend to satisfy a
skill. Do not launch nested agent CLIs through `bash`.

When delegation is unavailable, disclose that limitation and perform supported
steps inline. Preserve the workflow's scope, evidence requirements, and review
criteria. Sequential passes are not independent or multi-model review. If a
step requires independent agents, unavailable models, or enforced read-only
execution, mark that step unavailable rather than claiming it passed.

If the user has separately provided an advertised delegation tool, read its
actual schema and guide before using it. Check its available agents, models,
context inheritance, and effective permissions rather than assuming bundled
briefs are registered. Include this contract's and the relevant skill's absolute
paths in each brief. Await results before depending on them. Work requiring
parent approval hooks stays in the parent unless the tool demonstrably preserves
those hooks. A prompt does not enforce a read-only boundary.

Use the current session's model. Never translate Cursor model slugs or effort
suffixes into guessed Pi model IDs, or copy Cursor tool arguments blindly.
Use another model only through an explicitly configured, verified capability.

For `setup-pstack`, explain that Pistack supplies skills only, with no model-role
router or agent configuration to generate. Do not write `.cursor/rules` or
`pstack-models.json`, change the session model, or install a backend. If the user
explicitly requests configuration of a separately installed capability, consult
its guide and confirm model choices before writing its supported configuration.

## Sessions and helpers

Use only the current project's Pi session evidence through installed session
tools or runtime-supplied paths. Do not scan Cursor transcripts or unrelated
projects. If evidence is unavailable, use a clearly labeled current-session
digest and disclose the limitation.

The installed package is immutable. Helpers may require Bash, Git, jq, gh,
Bun, mise, network downloads, or other dependencies. Before running a helper
that writes beside itself or bootstraps dependencies, copy its complete scripts
directory to a fresh writable temporary directory. Run the copied helper from
the task's working directory, allow downloads only within existing authority,
and remove the copy afterward. Never install dependencies in the Nix store.
