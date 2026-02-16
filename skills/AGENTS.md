# Skills Catalog (Child Flake)

Manages agent skills for claude, pi, and opencode via `agent-skills-nix`.

## How It Works

`skills/flake.nix` is a child flake (separate lock file). It defines:

1. **Sources** — where skills come from (local dir or remote repos)
2. **Skill selection** — which skills to enable
3. **Targets** — which agents get the skills (symlink-tree into `~/.claude/skills/`, `~/.pi/agent/skills/`, `~/.config/opencode/skill/`)

## Adding a Local Skill

Drop a directory with `SKILL.md` into `config/agents/skills/<name>/`. Auto-enabled via `skills.enableAll = ["local"]`.

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
   cd .. && nix flake update skills-catalog
   ```

**⚠️ CRITICAL: Whenever you change `skills/flake.nix` or `skills/flake.lock`, you MUST also run `nix flake update skills-catalog` from the repo root to sync the parent lock. Forgetting this causes `attribute 'xxx' missing` errors at rebuild time.**

## Updating Remote Skills

```bash
# Update child lock
cd skills && nix flake update  # update all
cd skills && nix flake lock --update-input openai-skills  # update one

# THEN sync parent lock (REQUIRED)
cd .. && nix flake update skills-catalog
```

Then `hey rebuild`.

## Current Sources

| Source        | Repo                     | Skills             |
| ------------- | ------------------------ | ------------------ |
| local         | `config/agents/skills/`  | all (auto-enabled) |
| pi-extensions | `tmustier/pi-extensions` | extending-pi       |
| gitbutler     | `gitbutlerapp/gitbutler` | but                |
| openai        | `openai/skills`          | gh-fix-ci          |
