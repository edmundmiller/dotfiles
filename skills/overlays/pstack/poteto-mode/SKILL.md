---
name: poteto-mode
description: Runs pstack's engineering playbooks for investigation, implementation, review, and verification. Use when asked for pstack, poteto mode, or a pstack workflow.
---

# Pstack for Codex

This is a local compatibility port, not an upstream-supported Codex
plugin. The complete pinned pstack distribution is in `.upstream/` beside this
file. Read `.upstream/skills/poteto-mode/SKILL.md`, then the playbook it selects.
For help, read `.upstream/skills/poteto-help/SKILL.md`. For another pstack skill,
read `.upstream/skills/<name>/SKILL.md`. Resolve relative links from the upstream
file you are reading, not from this entry point.

This adapter overrides incompatible upstream instructions throughout
the bundle, including instructions read by delegates. Include this entry
point's absolute path in every delegate brief and require the delegate to read
it first.

## Permissions and scope

Pstack does not grant permission to publish, push, merge, deploy, send messages,
update tickets, launch external jobs, or delete data. Follow the user's current
authorization and applicable repository and runtime rules. A playbook is not
authorization. Do not modify installed skills or host configuration to repair a
missing capability. Report the limitation and continue with supported steps.

## Runtime mapping

- Treat `/name` and bold skill names as instructions to read the corresponding
  `.upstream/skills/<name>/SKILL.md`. They are not installed slash commands.
  The bundled `unslop`, `tdd`, and `teach` remain private to pstack so they do
  not replace the existing shared skills with those names.
- Codex delegation uses its advertised native agent tools, such as
  `spawn_agent`, `wait_agent`, and `list_agents`. Use only fields supported by
  the session's tool schema. `Task`, `subagent_type`, `run_in_background`, and
  Cursor model slugs are not Codex tool arguments. Read the desired agent brief
  from `.upstream/agents/` and include its relevant instructions in the prompt.
- Never launch nested agent CLIs to emulate delegation.
- Do not claim diverse-model agreement when running sequential passes or using
  one model. Cursor model roles and `pstack-models.mdc` do not configure these
  runtimes. Keep the session's configured model. `setup-pstack` must explain
  this limitation and stop without writing model rules.
- For questions, use Codex's `request_user_input` when available and allowed,
  otherwise ask in chat. Keep task lists in
  the runtime's native planning tool when available, or in concise chat updates.
- Use native file-reading and search tools, or shell `rg`. Never invent a
  missing tool. Resolve external skill dependencies such as `deslop`,
  `create-skill`, `control-cli`, and `control-ui` from the current runtime's
  available skills. If absent, perform supported checks and disclose the gap.
- Cursor Automations, Bugbot, Cursor cloud agents, and Cursor's PR tool are not
  provided by this port. Skip unavailable services rather than simulating them.
- Transcript analysis is limited to the current session and workspace. Use
  paths supplied by the runtime. Do not search Cursor's transcript directory
  or unrelated Codex sessions. If unavailable, use a labeled session digest.

## Executable helpers

The upstream shell helpers need Bash, Git, and sometimes `jq` and `gh`. The
TypeScript helpers need Bun and bootstrap dependencies beside their scripts.
Do not install dependencies into a Nix store path or the managed skill tree.
When a helper is needed, copy its entire `.upstream/skills/poteto-mode/scripts/`
directory to a fresh writable temporary directory, make the copy user-writable,
and run the helper there from the task's working directory. Allow its frozen
lockfile bootstrap only when network access is permitted. Remove the temporary
copy afterward. If a dependency is missing, report it instead of claiming that
the helper ran.
