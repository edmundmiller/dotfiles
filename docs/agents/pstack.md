---
purpose: Explain the pinned pstack integration for Claude Code, Codex, and Pi.
applies_to: Pstack plugins, Pi delegation, and the Codex poteto-mode skill.
entrypoint: config/claude/settings.json, config/pi/settings.jsonc, and skills/flake.nix.
verification: Run agent instruction tests, plugin bootstrap tests, Pi settings validation, and scoped hey check.
update_when: Pstack pins, runtime adapters, or installation behavior changes.
---

# Pstack

Adopted from [the Claude Code support announcement](https://x.com/cu30rry_/status/2111227122308300976).
The source is [cursor/plugins](https://github.com/cursor/plugins/tree/main/pstack).
Claude Code and Codex share one pinned revision. Pi uses the
[native port](https://github.com/0xrsydn/pstack-pi) from
[this announcement](https://x.com/0xrsydn/status/2111313240684994721).
The workflows are explicit skills, not new shared startup instructions.
Pi's extension loads at startup; invoking a skill is not an activation gate.

## Claude Code

Nix links the pinned upstream repository at `~/.claude/pstack-marketplace`.
The settings bootstrap registers its absolute path as the `cursor-plugins`
marketplace, disables marketplace auto-updates, and enables
`pstack@cursor-plugins`. This loads upstream's generated Claude Code adapter.
A GitHub marketplace `ref` cannot pin a commit because Claude clones it as a
branch or tag. The local Nix source avoids that limitation. After an
authorized host rebuild, start a fresh session and invoke `/pstack:poteto-mode`.
Use `/pstack:poteto-help` for upstream help. If Claude reports the plugin as
not installed, run `/plugin install pstack@cursor-plugins` in that session.

Claude's own permissions, the user's authorization, and repository rules still
apply. Pstack's broader autonomy instructions do not grant external-write or
deployment authority. Its Cursor-specific model routing is not available.

## Codex

Upstream does not support Codex directly. The local adapter is
`skills/overlays/pstack/poteto-mode/SKILL.md`, deployed as `poteto-mode` only to enabled
Codex modules. Use `$poteto-mode` and ask for a named pstack workflow through
that entry point.

The complete upstream distribution is nested in the skill's hidden `.upstream/`
directory so Codex's recursive discovery does not register its internal skills.
The bundle retains relative links, playbooks, docs, agent briefs, scripts, and
the MIT license.
Internal skills are not registered separately, so pstack's `tdd`, `teach`, and
`unslop` do not shadow the existing shared skills. Codex uses native delegation
when available. It must not claim multi-model review when using one model,
launch nested agent CLIs, or write Cursor model rules.

Executable TypeScript helpers need Bun and a writable copy of the scripts
directory for dependency bootstrap. The adapter describes this copy-and-cleanup
procedure. Installing the skill does not install or run those helpers.

## Pi

`packages/pstack-pi/default.nix` pins and patches the native package.
Home Manager links its immutable source at `~/.pi/agent/packages/pstack-pi`,
which `config/pi/settings.jsonc` loads as a local package. Pi's mutable Git
cache is not used. The pin includes the Pi session-history fix for
`automate-me`, which is absent from the `v0.16.0` tag.
The port requires Pi >=1.1. The existing Pi 1.3.0 selection in
`overlays/pi/default.nix` meets that requirement without a runtime change.

Use `/skill:poteto-mode`. Other package-native workflows include `/skill:arena`
and `/skill:swarm`. `/setup-pstack` configures role models and thinking levels
using Pi's authenticated model registry. Its writable config lives at
`~/.pi/agent/pstack-models.json`. The parent chat's default model is unchanged.
Without a role config, the extension tries its upstream model pair and falls
back to the parent for unavailable model families.

The package loads `pstack_task` for single, parallel, and chained child Pi
processes. Parallel calls accept eight tasks with four children at a time.
Children receive their brief, not the parent's conversation, and load their
own global Pi resources. They do not inherit parent-only CLI extensions or
parent CLI restrictions such as `--tools`, `--exclude-tools`, and `--no-mcp`.
Do not assume a child has the same restrictions as its parent.
`readonly` restricts ordinary tools; it is not a sandbox for extensions or MCP.
Repository rules and existing authorization still apply to every delegate.

Top-level `readonly` is supported only for single tasks. The carried patch
rejects it on `tasks[]` and `chain[]` before spawning children rather than
silently dropping the restriction. Set `readonly` on every batch item that
needs it, for example:

```json
{
  "tasks": [{ "agent": "general-purpose", "task": "Review the change", "readonly": true }]
}
```

The package's `tdd`, `teach`, and `unslop` are excluded from discovery to keep
existing shared skills. They remain in the package for relative references.
No second catalog copy of `poteto-mode` is installed for Pi.

This port does not provide durable background jobs, resumed child sessions,
automatic worktrees, or Cursor Cloud Automations. Some advanced playbooks
still describe those features. Use only the advertised tool schema and
supported foreground delegation; do not claim upstream parity.

## Updating and rollback

Update the pstack revision in `skills/flake.nix`. Claude uses that same child
input rather than a second pin. Review upstream changes and the local adapter.
Regenerate the child lock and synchronize the parent lock without activation. `hey skills-sync`
also rebuilds the host and requires activation authority. Run the scoped checks
before an authorized rebuild.

Update Pi's source revision and hash in `packages/pstack-pi/default.nix` and
the matching ref in its `package-harness.json`. Review the runtime requirements,
carried patch, and skill exclusions. Run `pkg-check pstack-pi` and build the
package before an authorized rebuild. After activation, restart Pi or run
`/reload` and verify `readlink -f ~/.pi/agent/packages/pstack-pi` resolves to
the expected store path from `nix build --no-link --print-out-paths .#pstack-pi`.
No `pi update` or Git cache reconciliation is needed for this local package.

To roll back, restore the previous source and both lockfiles, then use the
guarded rebuild command with authorization. Removing this integration disables
the Claude plugin, removes the Codex entry point, and stops loading Pi's
package on activation. It does not delete runtime-owned plugin caches or
Pi's model-role config. For a Pi package rollback, restore its Nix pin, hash,
patches, and harness ref, rebuild with authorization, verify the package symlink,
and restart Pi or run `/reload`. Old cached Git checkouts may remain on disk but
are not loaded.
