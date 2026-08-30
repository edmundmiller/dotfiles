---
name: pi-nix-syntax
description: >
  Use when converting Pi config/extension/skill setup (Pi settings.json packages, ~/.pi/agent/extensions,
  git:... sources) into this dotfiles repo's Nix representation (skills/flake.nix backed by agent-skills-nix,
  modules/agents/pi/default.nix home.file links), or converting the other direction.
---

# Pi ↔ Nix syntax conversions (this repo)

This repo intentionally splits responsibilities:

- **Pi packages + extensions** live in: `config/pi/settings.jsonc` (rendered to `~/.pi/agent/settings.json`).
- **Local Pi extensions** live in: `config/pi/extensions/*.ts` and are linked into `~/.pi/agent/extensions/` by Nix.
- **Shared skills** are not loaded via Pi `packages[].skills`; they are installed
  via **agent-skills-nix** (child flake `skills/`). Package-native skills remain
  an explicit exception.

If you see skills collisions, it usually means skills were enabled both ways.

## Canonical mapping

### 1) Pi settings.jsonc packages → stays Pi syntax (no Nix rewrite)

If the thing you’re converting is a Pi `packages` entry like:

```jsonc
{
  "source": "git:github.com/tmustier/pi-extensions",
  "extensions": ["tab-status/tab-status.ts"],
  "skills": [],
}
```

…then in this repo it should generally **remain** a `config/pi/settings.jsonc` entry.

Nix only ensures the file gets placed at `~/.pi/agent/settings.json`.

### 2) Local extension file → Nix home.file symlink

**Pi-style**: “I want this TS file to be a Pi extension.”

**Nix-style (this repo)**:

1. Put code in:
   - `config/pi/extensions/<name>.ts`
2. Link it into Pi extensions dir via:
   - `modules/agents/pi/default.nix` → `home-manager.users.<user>.home.file.".pi/agent/extensions/<name>.ts".source = "${configDir}/pi/extensions/<name>.ts";`

Rule: **anything under `~/.pi/agent/extensions/*.ts` must default-export a factory**.

### 3) Pi skills → agent-skills-nix catalog

Do not use `config/pi/settings.jsonc` `packages[].skills` for shared skills that
agent-skills-nix manages. Preserve intentionally package-native resources, such
as `pi-amplike`'s bundled `session-query` skill, unless they collide with a
catalog-managed copy.

Instead:

- Shared/global skills: add `skills/catalog/<skill-name>/SKILL.md`.
  - auto-enabled in `skills/flake.nix` with
    `skills.enableAll = [ "catalog" ];`
  - installed into the harness-neutral `~/.agents/skills/` target.
- Dotfiles-only project skills: add `.agents/skills/<skill-name>/SKILL.md`.
  - discovered only while working in this repository; never deploy them into
    the global catalog.
- Remote/pinned skills: add to `skills/flake.nix`:
  - declare `inputs.<src> = { url = "..."; flake = false; };`
  - `programs.agent-skills.sources.<src> = { path = inputs.<src>.outPath; ... }`
  - `programs.agent-skills.skills.explicit.<skillId> = { from = "<src>"; path = "..."; }`
  - for a Pi-only skill, use
    `programs.dotfiles-agent-skills.targetedExplicit.<skillId>` with
    `meta.targets = [ "pi" ];`

After changing a remote input, update the child lock and then synchronize the
parent lock through the guarded repository command:

```bash
cd skills && nix flake lock --update-input <src>
cd .. && hey skills-sync
```

Rule: avoid nested-symlink collisions by **flattening** nested IDs (example: `skill-creator` instead of `extending-pi/skill-creator`).

## Conversions

### Pi → Nix (how to implement in this repo)

Given a Pi-ish request, classify it:

1. **Remote extension package** (git:, npm:, https:):

- Put/keep it in `config/pi/settings.jsonc` under `packages`.

2. **Local extension** (your own `.ts`):

- Create `config/pi/extensions/<name>.ts`.
- Add a `home.file` link in `modules/agents/pi/default.nix`.

3. **Skill** (SKILL.md):

- If it should be shared across projects: create
  `skills/catalog/<name>/SKILL.md`.
- If it is specific to this dotfiles repository: create
  `.agents/skills/<name>/SKILL.md`.
- If remote: pin via `skills/flake.nix` (child flake) and select via `skills.explicit`.
- Do not add catalog-managed shared skills to Pi package arrays. Preserve
  deliberate package-native skills when they have no catalog-managed copy.

### Nix → Pi (how to express the effective Pi result)

1. If Nix is linking a file into `~/.pi/agent/extensions/<x>.ts`, then the Pi-side view is simply:

- “There exists an extension at `~/.pi/agent/extensions/<x>.ts`.”
- No `settings.json` change required.

2. If Nix is generating `~/.pi/agent/settings.json` from `config/pi/settings.jsonc`, then the Pi-side view is:

- “My Pi packages list includes …” (copy the JSONC stanza).

3. If Nix installs skills via agent-skills-nix, then the Pi-side view is:

- “Shared skills exist on disk in `~/.agents/skills/<name>/SKILL.md`.”
- “Pi-targeted skills exist on disk in
  `~/.pi/agent/skills/<name>/SKILL.md`.”
- They are **not** sourced from Pi `packages[].skills`.

## Quick templates

### Add a new shared skill

- Path: `skills/catalog/<name>/SKILL.md`
- Frontmatter must match directory name.

### Add a dotfiles-only project skill

- Path: `.agents/skills/<name>/SKILL.md`
- Frontmatter must match directory name.

### Add a new local extension

- Path: `config/pi/extensions/<name>.ts`
- Must: `export default function (pi: ExtensionAPI) { ... }`
- Link in `modules/agents/pi/default.nix` under `home.file`.
