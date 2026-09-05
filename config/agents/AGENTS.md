# Shared agent configuration

`core.md` supplies startup instructions for OMP, Codex, Claude, Pi, and OpenCode;
its limit is 220 words. Keep task procedures in skills or scoped guides.
`modes/` deploys to `~/.claude/agents` and the OpenCode V2 agent directory.

- Global skills: `skills/catalog/`, with selection and target wiring in
  `skills/flake.nix`; see [skills guidance](../../skills/AGENTS.md).
- Dotfiles-only skills: `.agents/skills/`; excluded from global deployment.
- Default shared target: `~/.agents/skills`. Runtime-specific targets are
  synchronized only for enabled modules and explicitly targeted skills.
- Claude does not discover that shared directory. Its module links only
  `test-quality`, `github-cli-media`, and `lore` into `~/.claude/skills`, preserving
  one canonical copy for OMP's name-based discovery.
- OMP conditional rules live in `config/omp/rules/` (TTSR). Other runtimes use
  their native scoped instructions, skills, hooks, and checks.
- OpenCode V2 loads its global `AGENTS.md`, not the legacy `instructions` array.

Package and runtime deployment belong to the matching `modules/agents/` module;
Plannotator integration belongs to `modules/agents/plannotator/`.
