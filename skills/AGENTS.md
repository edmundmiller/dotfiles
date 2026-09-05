# Shared skills catalog

`skills/flake.nix` is a child flake with its own lock. `catalog/<name>/SKILL.md`
is auto-enabled globally; dotfiles-only skills belong in `.agents/skills/`.
Source selection and target mappings live in the child flake.

## Deployment ownership

Default skills target `~/.agents/skills`, shared by OMP, Pi, Codex, Amp, OpenCode,
and Hermes. Agent-specific directories are for targeted skills only. Claude's
module links only `test-quality`, `github-cli-media`, and `lore` to canonical
shared copies; copying the full catalog there duplicates OMP discovery.
`meta.targets` accepts canonical names and `dot-*` aliases. Hermes additionally
needs its configured `skills.external_dirs` wiring.

Marker-aware activation adopts old markerless Nix trees only when managed
entries retain epoch timestamps. Mutable `.system` is ignored; newer entries
or symlinks preserve the overwrite guard rather than replacing local edits.

## Changes and checks

- Local metadata/content needs no manufactured lock change. Validate with
  `python3 skills/catalog/skill-quality/scripts/validate.py <skill-directory>`.
- Remote sources use pinned `flake = false` inputs and explicit selection.
  `hey skills-update` updates the child lock. `hey skills-sync` syncs the parent
  **and rebuilds the host**; run it only with activation authority. Child input
  changes need the corresponding parent sync before deployment.
- For remote overlays, use a transform for SKILL.md-only edits, or
  `skills/overlays/<name>/` patches via `pkgs.applyPatches` for bundled resources.
  Patch failure on update must not silently discard local behavior.
- Keep generated skilld cache symlinks out of the catalog; they point at local
  runtime caches, not portable resources.
- `tests/skill-evals/` owns deterministic scorer/source contracts and opt-in
  live evaluation. A skipped live case is not behavior evidence.

Marimo selection is intentionally curated: core authoring/conversion, widgets,
WASM validation, interactive paper implementation, and pairing, not every
publishing/batch/no-feedback variant. Metadata cleanup does not expand selection.
