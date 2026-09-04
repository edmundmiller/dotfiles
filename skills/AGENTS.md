---
purpose: Manage the shared Nix-backed agent skills catalog.
applies_to: Adding, updating, selecting, or deploying global skills.
entrypoint: Edit skills/flake.nix or skills/catalog, then use the matching workflow.
verification: Rebuild the host and verify the expected target directories.
update_when: Skill sources, targets, selection, or sync workflows change.
---

# Skills Catalog (Child Flake)

Manages global agent skills via `agent-skills-nix`. Dotfiles project-local skills belong in `.agents/skills/`, not here, and must not be deployed globally.

## How It Works

`skills/flake.nix` is a child flake (separate lock file). It defines:

1. **Sources** — where skills come from (local dir or remote repos)
2. **Skill selection** — which skills to enable
3. **Targets** — where skills are installed (`~/.agents/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, `~/.config/opencode/skills`, `~/.hermes/skills`)

Default skills go only to `agents`. OMP, Pi, Codex, Amp, OpenCode, and Hermes read `~/.agents/skills`; their own dirs are for target-specific skills only. Claude does not read that shared directory, so its module exposes only `test-quality` and `github-cli-media` as symlinks to the canonical shared copies. Do not copy the full catalog into `~/.claude/skills`: OMP scans both locations. Target-specific skills use `meta.targets`, accepting canonical names (`agents`, `codex`, `pi`, `opencode`, `hermes`) or dot-name aliases (`dot-agents`, `dot-codex`, `dot-pi`, `dot-opencode`, `dot-hermes`).

## Upgrade safety

Marker-aware deployment adopts an older markerless Nix copy-tree only when all
managed entries retain Nix's epoch timestamp. Mutable `.system` content is
ignored. A symlink or newer entry leaves the upstream overwrite guard intact,
so activation stops instead of replacing locally modified content.

**Hermes note:** Hermes builtin skills do not include these dotfiles skills by default. In this repo, Hermes picks them up through `skills.external_dirs` pointing at `~/.hermes/skills`. If that external dir wiring is missing, Hermes falls back to builtin-only skills.

**Amp note:** Amp discovers `~/.agents/skills` natively and surfaces those skills under `/skill` in the TUI. `amp skill list` enumerates them after login. Add shared skills here instead of with `amp skill add` so Nix manages one copy for every agent.

**Claude note:** `modules/agents/claude/default.nix` owns the allowed shared
skill links, currently `test-quality`, `github-cli-media`, and `lore`. Keep
their targets under `~/.agents/skills`; OMP may scan both providers, but its
name-based discovery exposes one entry per skill and the symlinks keep the
selected content canonical.

## Adding a Global Skill

Drop a directory with `SKILL.md` into `skills/catalog/<name>/`. Use this only for skills that should be available across projects. Auto-enabled via `skills.enableAll = ["catalog"]`.

Run `hey skills-sync` from the repository root after adding or changing a
checkout-local skill. Local catalog content and target selection are read
directly from `./skills`; do not manufacture a `skills/flake.lock` change for
them.

For target-specific explicit skills, set metadata in `skills/flake.nix`:

```nix
programs.dotfiles-agent-skills.targetedExplicit.my-skill = {
  from = "my-source";
  path = "my-skill";
  meta.targets = [ "codex" "pi" ];
};
```

## Adding a Remote Skill

1. **Add flake input** (hash-pinned, `flake = false`):

   ```nix
   my-repo = {
     url = "github:org/repo";
     flake = false;
   };
   ```

2. **Add source** with `subdir` pointing to the skills parent directory:

   ```nix
   sources.my-repo = {
     path = inputs.my-repo.outPath;
     subdir = "path/to/skills";  # parent of skill dirs
     filter.maxDepth = 2;
   };
   ```

3. **Add explicit skill entry** (name = skill dir inside subdir):

   ```nix
   skills.explicit = {
     my-skill.from = "my-repo";
     my-skill.path = "my-skill";  # dir name under subdir
   };
   ```

4. **Lock child AND parent** (both steps required):
   ```bash
   cd skills && nix flake lock --update-input my-repo
   cd .. && hey skills-sync
   ```

**⚠️ CRITICAL: Whenever you change `skills/flake.nix` or `skills/flake.lock`, you MUST also run `hey skills-sync` from the repo root to sync the parent lock. Forgetting this causes `attribute 'xxx' missing` errors at rebuild time.**

## Overlaying a Remote Skill

Use an explicit skill `transform` when only `SKILL.md` changes. For scripts,
references, or tests, keep a patch under `skills/overlays/<name>/` and apply it
to the pinned input with `pkgs.applyPatches` before registering the source.
Build the overlaid bundle and run its focused tests; an upstream update that no
longer accepts the patch must fail instead of silently dropping local behavior.

## Updating Remote Skills

```bash
# Update child lock
cd skills && nix flake update  # update all
cd skills && nix flake lock --update-input openai-skills  # update one

# THEN sync parent lock (REQUIRED)
cd .. && hey skills-sync
```

## Adding a skilld-Generated Skill

[skilld](https://github.com/harlan-zw/skilld) generates SKILL.md files from npm package docs. To add one to the Nix-managed catalog:

1. **Generate the skill** in a temp directory:

   ```bash
   cd /tmp && mkdir skilld-gen && cd skilld-gen
   npm init -y && npx skilld add <package> --agent claude-code -y
   ```

2. **Copy the SKILL.md** into local skills:

   ```bash
   cp .claude/skills/<generated-name>/SKILL.md \
     skills/catalog/<package>/SKILL.md
   ```

   Skip the `.skilld/` symlinks — they point to runtime caches. The SKILL.md itself tells agents to use `npx -y skilld search` for lookups.

3. **Sync and rebuild**: `hey skills-sync` — auto-enabled via the checkout-local
   catalog source.

## Evaluating Global Skills

Skill behavior evals live in `tests/skill-evals/`. Run deterministic scorer and
source-contract tests before a live model eval:

```bash
cd tests/skill-evals
bun install --frozen-lockfile
bun run test
bun run evals:done
```

`evals:done` uses vitest-evals with an ephemeral, read-only Codex CLI run. Use
`evals:done:acpx` for a tool-disabled ACPX one-shot agent, and set
`DONE_SKILL_EVAL_AGENT` to choose another registered ACPX agent.

## Marimo Skill Curation

We intentionally do **not** enable every skill from `marimo-team/skills`.

Kept:

- `marimo-notebook` — core notebook authoring conventions
- `jupyter-to-marimo` — common migration path
- `streamlit-to-marimo` — common migration path
- `anywidget` — richer custom widget/UI work
- `wasm-compatibility` — useful validation niche
- `implement-paper` — interactive, user-steered paper workflow
- `marimo-pair` — separate repo; main live-notebook pairing capability

Removed from the enabled set:

- `add-molab-badge` — niche publishing helper; not broadly useful during normal coding flows
- `auto-paper-demo` — overlaps with `implement-paper`, but forces a no-feedback workflow
- `implement-paper-auto` — overlaps heavily with `implement-paper`; we prefer the interactive version
- `marimo-batch` — valid, but narrower than the core authoring/conversion skills we want loaded by default

Rule of thumb: prefer broad, reusable skills with low overlap. Avoid installing narrow helpers or duplicated "auto" variants unless we repeatedly need them.

## Discovering Current Sources

List inputs: `nix flake metadata skills/ --json | jq -r '.locks.nodes.root.inputs | keys[]'`. Skill source/mapping config lives in `skills/flake.nix` (`sources` and `skills.explicit` blocks). Local skills are auto-discovered from `skills/catalog/`.
