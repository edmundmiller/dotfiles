# Pistack on Pi

This is a local compatibility layer over Cursor's pinned pstack, not a Cursor
plugin or a fork of another Pi port. This contract overrides host-specific
instructions in every bundled skill, agent, playbook, and script description.
Read the upstream workflow for its reasoning and required evidence, then apply
these mappings to its execution. Include this file's absolute path in every
delegate brief and require the delegate to read it before acting.

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

Use the separately installed `pi-subagents` extension, not Cursor's `Task` or
the retired `pstack_task`. If only `subagents_enable` is advertised, enable
delegation through it first. Read the advertised `subagent` schema or installed
guide before calling it. A single blocking call uses
`{ agent: "pstack.poteto-agent", task: "...", async: false }`. Parallel work and
chains use its workflow-script interface by default, not top-level `tasks` or
`chain` arrays. Read the installed workflow guide before constructing them.
Map `subagent_type` to the native agent selection, preserve the brief and file
pointers, and include this contract's and poteto-mode's absolute paths. Use the
bundled `pstack.poteto-agent` for implementation and `pstack.comment-sicko` where
the workflow requests it. Other role names are task descriptions, not agent
definitions; choose an available native agent and put the role in its brief.

Use `async: false` when the next step requires completed findings. Background
calls return receipts, not results; await completion through the native backend
before claiming success. The bundled agents inherit project and global
instructions but not ambient extensions or the skill catalog. Their tools allow
implementation, not enforced read-only review. For a read-only requirement choose a native
read-only agent, inspect its effective tool allowlist, and include this contract
and the relevant upstream agent brief in its task.

Parent permission and approval hooks are not automatically inherited. If the
task relies on those hooks, confirm the backend's effective launch contract
includes them as required child extensions before delegating. Otherwise keep
that work in the parent. Do not substitute a prompt for an enforced boundary.

Never copy `run_in_background`, resume IDs, Cursor model slugs, or readonly
flags blindly into Pi tool arguments. Use only capabilities the installed
schema advertises. Do not launch nested agent CLIs through `bash`. If delegation
is unavailable, disclose the gap and do supported work inline. Do not represent
sequential passes as independent or multi-model review.

Use the parent model unless a user-configured native agent or an explicit,
verified provider/model selection supplies another. Cursor's effort and speed
suffixes are not Pi model IDs. Preserve diverse-model review only when those
models are actually available. A read-only brief is an instruction, not a
sandbox. Use the backend's supported tool restrictions when required and do
not claim they restrict extensions, MCP, or arbitrary shell execution.

For `setup-pstack`, do not follow the Cursor rule-writing procedure. Read the
installed pi-subagents model/agent configuration guide, discover available
models using its supported interface, and propose native agent configuration.
Confirm user choices before writing. Do not write `.cursor/rules`, assume the
old port's `pstack-models.json` is consumed, or change the parent chat's model.

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
