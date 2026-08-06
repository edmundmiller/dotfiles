---
name: omp-model-config
description: Configure OMP model roles, providers, fallback chains, and per-host overrides in this nix-darwin dotfiles repo. Use when changing which models OMP uses, shifting providers, fixing fallback chains, or troubleshooting why a model change didn't take effect after rebuild.
---

# OMP Model Configuration

## How OMP model config works

OMP reads `~/.omp/agent/config.yml` at runtime. This file is a Nix-managed
symlink deployed by `modules/agents/omp/default.nix`. The module starts from
the shared base at `config/omp/config.yml` and overlays per-host settings from
`hosts/<host>/default.nix` at build time using `yq`.

Two layers:

1. **Shared defaults** in `config/omp/config.yml` — `modelRoles`, `retry`,
   `compaction`, `advisor`, etc. Edit this for changes that apply to all hosts.
2. **Per-host overlays** in `hosts/<host>/default.nix` under
   `modules.agents.omp` — `smolModel`, `modelRoles`, `modelProviderOrder`,
   `retry.modelFallback`, `retry.fallbackChains`. These override the shared
   defaults via yq expressions at build time.

Source of truth for providers: the block comments in each host's `default.nix`
and the `omp models <provider>` command on that host. Providers are
host-specific. Never cross-wire prefixes across laptops or invent hybrid ids.

## The Nix options

```nix
modules.agents.omp = {
  enable = true;

  # Sets PI_SMOL_MODEL in the omp wrapper binary via makeWrapper --set.
  # Precedence: --smol flag > PI_SMOL_MODEL > config.yml modelRoles.smol.
  # Requires a rebuild to change (baked into the binary, not config.yml).
  smolModel = "provider/model";

  # Overlays these keys onto config.yml's modelRoles at build time.
  # Each value is "provider/model-id" or "provider/model-id:reasoning-level".
  modelRoles = {
    default = "provider/model:low";    # general workhorse
    smol = "provider/fast-model";      # quick/fast operations
    slow = "provider/model:high";      # deep reasoning
    plan = "provider/model:high";      # planning
    advisor = "provider/model:high";   # cross-check reviewer
    task = "provider/fast-model";      # delegated subtasks
    commit = "provider/fast-model";    # commit messages
    tiny = "provider/fast-model";      # metadata, trivial work
    designer = "provider/model:high";  # design/architecture
    vision = "provider/vision-model";  # image analysis (must support images)
  };

  # Provider resolution order for ambiguous canonical model ids.
  # List providers in priority order. Remove providers you don't want resolving.
  modelProviderOrder = [ "provider-a" "provider-b" ];

  retry.modelFallback = true;  # enable per-role fallback chains

  # Per-role fallback chains. When the primary model fails, OMP tries each
  # entry in order. These REPLACE the base config.yml chains for the roles
  # you specify (they don't merge).
  retry.fallbackChains = {
    default = [ "provider-b/model:high" "provider-c/model:high" ];
    advisor = [ "provider-b/model:high" ];
    # ... one per role that needs a chain
  };

  # Override the daily introspection model (module defaults to
  # openai-codex/gpt-5.6-sol:high). Without this, the nightly launchd job
  # will use the default, which may be a provider you're trying to avoid.
  dailyIntrospection.model = "provider/model:high";
};
```

## Validating models before adding them

```bash
omp models <provider>
```

Check the output table:

- **model**: Must match the id you're pinning (without the `provider/` prefix).
- **thinking**: Lists supported reasoning levels. A `-` means no reasoning
  levels. Do NOT append `:high` or `:low` to these models (e.g.,
  `grok-composer-2.5-fast` has `-`; `grok-4.5` has
  `minimal,low,medium,high,xhigh`).
- **images**: Must be `yes` for the `vision` role.
- **context** / **max-out**: Useful for choosing smol vs slow models.

Never guess model ids. Always validate with `omp models` on the target host
before adding roles or fallbacks.

## Fallback chain rules

1. **No redundant first hop**: The primary model must not appear as the first
   fallback. It already failed, so trying it again wastes a hop.
2. **No invalid reasoning levels**: Check `omp models` output. Models with `-`
   in thinking don't support `:high`, `:low`, etc.
3. **Cross providers**: At least one fallback on a different provider than the
   primary. If all fallbacks are on the same provider and it goes down, every
   hop fails.
4. **Cover all roles**: `advisor`, `task`, and `commit` often don't have
   chains in the base config. Add them if you want fallback protection.
5. **Openrouter as last resort**: `openrouter/moonshotai/kimi-k3:high` (or
   similar) is a good final hop since it's pay-per-use and rarely rate-limited.

## Rebuild and deploy

```bash
hey check   # validate Nix evaluation
hey re      # rebuild and switch
```

`hey re` runs `darwin-rebuild switch --flake ~/.config/dotfiles#<host>`. It
builds from the **main checkout** (`~/.config/dotfiles`), not the current
worktree. If you're editing in a worktree, apply the same edit to
`~/.config/dotfiles` or the rebuild won't pick it up.

## Footguns

### `hey re` builds from `~/.config/dotfiles`, not the worktree

The `hey` wrapper resolves `flake_dir` by checking `$FLAKE_DIR`, then walking
up from `$cwd`, then falling back to `~/.config/dotfiles`. In practice, the
fallback often wins. Always mirror worktree edits to `~/.config/dotfiles` if
you need the rebuild to take effect immediately.

### `config.yml` symlink may not update after rebuild

`home.file.".omp/agent/config.yml"` has `force = true`, but the home-manager
activation step can silently fail to update the symlink. The omp wrapper
binary (`PI_SMOL_MODEL`, `PI_CODING_AGENT_DIR`) and launchd scripts
(`dailyIntrospection.model`) do get rebuilt, but `config.yml` can stay stale.

After rebuilding, always verify:

```bash
grep -c 'provider-you-removed' ~/.omp/agent/config.yml  # should be 0
file ~/.omp/agent/config.yml                              # should be symlink
```

If stale, manually replace:

```bash
TMP=$(mktemp)
cat ~/.omp/agent/config.yml > "$TMP"
sed -i '' -e 's|old-provider/old-model|new-provider/new-model|g' "$TMP"
rm -f ~/.omp/agent/config.yml
cp "$TMP" ~/.omp/agent/config.yml
rm -f "$TMP"
```

Then manually fix fallback chains (sed can't do structural YAML changes).

### `PI_SMOL_MODEL` is baked into the wrapper binary

`smolModel` in Nix sets `PI_SMOL_MODEL` via `makeWrapper --set` in the omp
wrapper script. This is baked at build time, not read from `config.yml`.
Precedence: `--smol` flag > `PI_SMOL_MODEL` > `config.yml modelRoles.smol`.

If the rebuild updates the wrapper but not `config.yml`, the smol model will
come from `PI_SMOL_MODEL` (correct) while other roles come from the stale
`config.yml` (wrong). Always verify both.

### `dailyIntrospection.model` has a hardcoded default

The module defaults `dailyIntrospection.model` to
`openai-codex/gpt-5.6-sol:high`. If you're shifting off openai-codex and
forget to override this, the nightly launchd job (`omp-thread-introspection`)
will silently burn quota on the provider you're avoiding. Set it explicitly:

```nix
dailyIntrospection.model = "alternative-provider/model:high";
```

### `retry.fallbackChains` replaces, doesn't merge

The host's `fallbackChains` overlay replaces the base config's chains for the
roles you specify. Roles you don't list keep their base config chains. If the
base config has `openai-codex` in a chain for a role you didn't override, that
chain will still reference the old provider.

### `modelRoles` values need exact provider prefixes

Model ids are `provider/model-id` or `provider/model-id:reasoning-level`. The
provider prefix must match a provider registered on that host. Never invent
hybrid ids like `cursor/grok-*`. Validate with `omp models <provider>`.
