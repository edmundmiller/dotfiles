---
name: pi-nix-syntax
description: >
  Use when converting Pi config/extension/skill setup (Pi settings.json packages, ~/.pi/agent/extensions,
  git:... sources) into this dotfiles repo's Nix representation (skills-catalog/agent-skills-nix,
  modules/shell/pi/default.nix home.file links), or converting the other direction.
---

# Pi ↔ Nix syntax conversions (this repo)

This repo intentionally splits responsibilities:

- **Pi packages + extensions** live in: `config/pi/settings.jsonc` (rendered to `~/.pi/agent/settings.json`).
- **Local Pi extensions** live in: `config/pi/extensions/*.ts` and are linked into `~/.pi/agent/extensions/` by Nix.
- **Skills** are **not** loaded via Pi `packages[].skills` anymore; skills are installed via **agent-skills-nix** (child flake `skills/`).

If you see skills collisions, it usually means skills were enabled both ways.

## Canonical mapping

### 1) Pi settings.jsonc packages → stays Pi syntax (no Nix rewrite)

If the thing you’re converting is a Pi `packages` entry like:

```jsonc
{
  "source": "git:github.com/tmustier/pi-extensions",
  "extensions": ["tab-status/tab-status.ts"],
  "skills": []
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
   - `modules/shell/pi/default.nix` → `home-manager.users.<user>.home.file.".pi/agent/extensions/<name>.ts".source = "${configDir}/pi/extensions/<name>.ts";`

Rule: **anything under `~/.pi/agent/extensions/*.ts` must default-export a factory**.

### 3) Pi skills → agent-skills-nix catalog

We do **not** use `config/pi/settings.jsonc` `packages[].skills` for installing skills.

Instead:

- Local skills: add `config/agents/skills/<skill-name>/SKILL.md`.
  - auto-enabled (see `skills/flake.nix`: `skills.enableAll = ["local"]`).
- Remote/pinned skills: add to `skills/flake.nix`:
  - `programs.agent-skills.sources.<src> = { path = inputs.<src>.outPath; ... }`
  - `programs.agent-skills.skills.explicit.<skillId> = { from = "<src>"; path = "..."; }`

Rule: avoid nested-symlink collisions by **flattening** nested IDs (example: `skill-creator` instead of `extending-pi/skill-creator`).

## Conversions

### Pi → Nix (how to implement in this repo)

Given a Pi-ish request, classify it:

1) **Remote extension package** (git:, npm:, https:):
- Put/keep it in `config/pi/settings.jsonc` under `packages`.

2) **Local extension** (your own `.ts`):
- Create `config/pi/extensions/<name>.ts`.
- Add a `home.file` link in `modules/shell/pi/default.nix`.

3) **Skill** (SKILL.md):
- If local: create `config/agents/skills/<name>/SKILL.md`.
- If remote: pin via `skills/flake.nix` (child flake) and select via `skills.explicit`.
- Ensure `config/pi/settings.jsonc` package entries have `"skills": []` to avoid collisions.

### Nix → Pi (how to express the effective Pi result)

1) If Nix is linking a file into `~/.pi/agent/extensions/<x>.ts`, then the Pi-side view is simply:
- “There exists an extension at `~/.pi/agent/extensions/<x>.ts`.”
- No `settings.json` change required.

2) If Nix is generating `~/.pi/agent/settings.json` from `config/pi/settings.jsonc`, then the Pi-side view is:
- “My Pi packages list includes …” (copy the JSONC stanza).

3) If Nix installs skills via agent-skills-nix, then the Pi-side view is:
- “Skills exist on disk in `~/.pi/agent/skills/<name>/SKILL.md`.”
- They are **not** sourced from Pi `packages[].skills`.

## Quick templates

### Add a new local skill

- Path: `config/agents/skills/<name>/SKILL.md`
- Frontmatter must match directory name.

### Add a new local extension

- Path: `config/pi/extensions/<name>.ts`
- Must: `export default function (pi: ExtensionAPI) { ... }`
- Link in `modules/shell/pi/default.nix` under `home.file`.
