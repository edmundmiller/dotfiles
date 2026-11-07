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
Claude Code and Codex share one pinned revision. Pi independently pins Cursor's
upstream content and applies local compatibility patches. It does not depend on
another pstack port. The unchanged upstream plus adapter design takes ideas from
[sndrgrdn's port](https://github.com/sndrgrdn/pstack-pi), and checked deterministic
updates from [aaalexliu's port](https://github.com/aaalexliu/pstack-pi).
The workflows are explicit skills, not new shared startup instructions.
Pi's separate delegation backend loads at startup; invoking a skill is not an
extension activation gate.

## Claude Code

Pstack defaults on when `modules.agents.claude.enable` is enabled. The NUC
enables only `modules.agents.claude.pstack.enable` because it already installs
Claude as an agent backend. This mode merges only the pstack plugin and
marketplace entries into existing settings. It preserves permissions, hooks,
environment, other plugins, and all other settings without taking over
Claude's instructions, skills, or MCP configuration.

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

## Pi (pistack)

`packages/pistack/package-harness.json` owns the full upstream commit and
ordered patch list. `default.nix` owns the matching fetch hash. Nix applies
the patches with `git apply --check`, without fuzz. `build.mjs` preserves the
upstream distribution, adds a link to `PI.md` after every skill's and agent's
frontmatter, and generates a native Pi package manifest. No LLM rewrites skills.
Content tests compare every packaged upstream file, allowing only those links.

Home Manager links the immutable package at `~/.pi/agent/packages/pistack`.
`config/pi/settings.jsonc` loads its manifest rather than a mutable Git cache.
Use `/skill:poteto-mode`, `/skill:sharpen`, `/skill:arena`, or `/skill:swarm`.
The manifest discovers new upstream skill directories automatically. `tdd`,
`teach`, and `unslop` stay private to preserve existing shared skills, but remain
on disk for relative references. The separate shared catalog still uses
`skills/flake.nix` and agent-skills-nix. There is no duplicate Pi catalog entry
for `poteto-mode` or `sharpen`.

Delegation uses the independently pinned `pi-subagents` package, not another
pstack port's runtime. It requires Pi >=1.2.0; the selected runtime version in
`overlays/pi/hashes.json` meets that requirement. The package manifest exposes `pstack.poteto-agent` and
`pstack.comment-sicko`. They inherit project and global instructions, use explicit ordinary
tool allowlists, and disable ambient extensions and the skill catalog. These
are implementation agents, not a read-only sandbox. User overrides and native
backend settings can change their effective configuration.

Parent permission hooks are not automatically inherited. Work requiring those
hooks stays in the parent unless the backend's effective launch contract
confirms they load as required child extensions.

`PI.md` maps Cursor `Task` to the advertised native schema. Blocking work uses
`async: false`; parallelism and chains use the backend's workflow interface.
Cursor model slugs, effort suffixes, resume IDs, and readonly flags are not
copied into native tool calls. `setup-pstack` instead consults native backend
configuration and asks before changing model choices. The old port's
`~/.pi/agent/pstack-models.json` is neither read nor deleted.

The adapter covers current-project session evidence and writable copies of
immutable helpers. It does not supply Cursor Cloud Automations, Bugbot,
artifact hosting, or a scheduler. Native backend features must be checked
against its installed guide. Permission rules and user authorization still
apply. No prompt adapter can guarantee model compliance or provide a sandbox.

## Updating and rollback

Update the pstack revision in `skills/flake.nix`. Claude uses that same child
input rather than a second pin. Review upstream changes and the local adapter.
Regenerate the child lock and synchronize the parent lock without activation. `hey skills-sync`
also rebuilds the host and requires activation authority. Run the scoped checks
before an authorized rebuild.

For Pi, run `node packages/pistack/update.mjs` from the checkout. An optional
full commit SHA selects a specific candidate. Without it, the updater selects
the latest commit touching upstream `pstack/`, not unrelated plugin changes.
It fetches a hash-pinned source, applies our patches in a writable temporary
copy, and runs the content tests before changing either pin file. A patch
conflict or failed content test leaves both files unchanged. Review the printed
upstream comparison, especially new Cursor-specific instructions. The updater
does not change the adapter, execute upstream helpers, or activate a host.

`.github/workflows/pistack-sync.yml` runs the same updater weekly and on manual
dispatch. It builds the Nix package and proposes a PR containing only the pin
and hash. It does not auto-merge. The repository must allow GitHub Actions to
create pull requests. This workflow and its schedule take effect only after
landing on the default branch. Delegation backend updates remain separate.

Run `pkg-check pistack`, the package build, Pi settings validation, and scoped
`hey check` before an authorized rebuild. After activation, restart Pi or run
`/reload` and verify `readlink -f ~/.pi/agent/packages/pistack` resolves to
the expected store path from `nix build --no-link --print-out-paths .#pistack`.
No `pi update` or Git cache reconciliation is needed for this local package.

To roll back, disable the Claude plugin with `claude plugin disable pstack@cursor-plugins`,
restore the previous source and both lockfiles, then use the guarded rebuild
command with authorization. Plugin-only hosts retain their writable Claude
settings when the Nix marketplace link is removed. Removing the integration
removes the Codex entry point and stops loading Pi's package on activation.
It does not delete runtime-owned plugin caches or Pi's model-role config.
For a Pi package rollback, restore its Nix pin, hash,
patches, adapter, builder, and matching settings, rebuild with authorization, verify the package symlink,
and restart Pi or run `/reload`. Old cached Git checkouts may remain on disk but
are not loaded.
