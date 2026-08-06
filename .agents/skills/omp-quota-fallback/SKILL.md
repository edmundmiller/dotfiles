---
name: omp-quota-fallback
description: Temporarily shift OMP model roles off a quota-limited provider (e.g., openai-codex at 3%) to alternative providers for a day. Use when a provider quota is about to run out, a banked reset should be preserved, or model roles need a short-term override without changing shared defaults.
---

# OMP Quota Fallback Override

## When to Use

- A provider quota (openai-codex, xai-oauth, etc.) is near exhaustion and resets within 24 hours
- The user wants to save a banked reset for a heavier day instead of burning it now
- A provider is temporarily down and roles need rerouting

## When NOT to Use

- Permanent provider changes (edit `config/omp/config.yml` defaults instead)
- Adding a new provider (follow `modules/agents/omp/AGENTS.md` per-host provider rules)
- Cross-host config changes (providers are host-specific; never cross-wire)

## Prerequisites

1. Run `hostname` and `uname -a` to confirm the target host.
2. Read the host's `default.nix` OMP block to see current providers and roles.
3. Read `config/omp/config.yml` for shared defaults that the host overlays.

## Workflow

### 1. Identify available providers and models

```bash
omp models <provider>
```

Run this for each non-quota-limited provider on the host. Check the `model`, `thinking`, and `images` columns:

- Ensure the model exists on that provider.
- Ensure the reasoning level suffix (`:low`, `:high`, etc.) is supported. Models showing `-` in the thinking column do not support reasoning levels (e.g., `grok-composer-2.5-fast`).
- Vision roles need `images: yes`.

### 2. Map roles to alternative providers

Spread load across providers. Don't put every role on one provider. General guidance:

| Role type                   | Good candidates                                         |
| --------------------------- | ------------------------------------------------------- |
| default (general workhorse) | Strong general model at low/medium reasoning            |
| slow (deep reasoning)       | Strongest model at high/xhigh reasoning                 |
| advisor/plan (analysis)     | Strong reasoning model, different provider from default |
| smol/task (fast, cheap)     | Flash/fast variant from a different provider            |
| commit/tiny (metadata)      | Fastest available model                                 |
| vision                      | Must support images                                     |
| designer                    | Strong reasoning model                                  |

### 3. Edit the host Nix config

Edit `hosts/<host>/default.nix` in the `modules.agents.omp` block:

```nix
omp = {
  # ... enable, smolModel, modelRoles, modelProviderOrder ...
  smolModel = "alternative-provider/fast-model";
  modelRoles = {
    default = "alt-provider/strong-model:low";
    smol = "alt-provider/fast-model";
    # ... etc, replace all quota-limited provider entries
  };
  modelProviderOrder = [
    # Remove the quota-limited provider, reorder alternatives first
  ];
  retry.modelFallback = true;
  retry.fallbackChains = {
    # Every role that had a chain needs a new one.
    # CRITICAL: Do NOT include the primary model as the first fallback (wasted hop).
    # CRITICAL: Do NOT use reasoning levels on models that don't support them.
    default = [ "alt-provider-2/strong-model:high" ];
    # Add chains for advisor, task, commit if they didn't have one before.
  };
  dailyIntrospection.model = "alt-provider/strong-model:high";
};
```

### 4. Apply to both the worktree AND the main checkout

`hey re` builds from `~/.config/dotfiles`, not the worktree. Apply the same edit to both:

```bash
# Worktree (for git history)
# Edit hosts/<host>/default.nix

# Main checkout (for the rebuild to pick it up)
# Edit ~/.config/dotfiles/hosts/<host>/default.nix
```

### 5. Rebuild

```bash
hey check
hey re
```

### 6. Verify the config.yml deployed

The `hey re` / `darwin-rebuild switch` may not update the `~/.omp/agent/config.yml` symlink (known home-manager activation issue). Check:

```bash
# Should show zero references to the quota-limited provider
grep -c 'quota-limited-provider' ~/.omp/agent/config.yml

# Should be a symlink to a Nix store path
file ~/.omp/agent/config.yml
```

If the count is nonzero or the symlink is stale:

```bash
# Manual fallback: replace symlink with a corrected copy
TMP=$(mktemp)
cat ~/.omp/agent/config.yml > "$TMP"
sed -i '' \
  -e 's|old-provider/old-model|new-provider/new-model|g' \
  "$TMP"
rm -f ~/.omp/agent/config.yml
cp "$TMP" ~/.omp/agent/config.yml
rm -f "$TMP"
```

Then fix fallback chains manually (see step 7) since sed won't handle structural changes.

### 7. Fix fallback chains if manually editing

If you manually edit `config.yml`, check every fallback chain for:

1. **Redundant first hop**: The primary model appears as the first fallback. Remove it.
2. **Invalid reasoning levels**: A model with `-` in the thinking column has a `:high` or `:low` suffix. Remove the suffix or swap the model.
3. **Missing chains**: Roles like `advisor`, `task`, `commit` that didn't have fallback chains before. Add them, crossing to a different provider.
4. **Same-provider-only chains**: If all fallbacks are on the same provider and that provider goes down, every hop fails. Cross to at least one other provider.

### 8. Verify providers are authenticated

```bash
omp models <each-alternative-provider>
```

Confirm every model ID used in the override appears in the output.

### 9. Write a revert reminder

Create a dated task note in the Obsidian vault:

```
~/obsidian-vault/01_Tasks/YYYY-MM-DD Revert OMP <provider> override.md
```

Include:

- The revert deadline (when the quota resets)
- Exact revert commands for both worktree and main checkout
- A verification snippet
- A table of what changed (role, override model, original model)

### 10. Commit the worktree change

```bash
git add hosts/<host>/default.nix
git commit -m "feat(omp): shift <host> models off <provider> for 1 day

<provider> quota at N%, resets YYYY-MM-DD.
Revert after YYYY-MM-DD."
```

Do NOT push. This is a throwaway commit.

## Reverting

```bash
# Worktree
cd <worktree>
git revert HEAD --no-edit

# Main checkout
cd ~/.config/dotfiles
git checkout -- hosts/<host>/default.nix

# Rebuild
hey re

# Verify
grep 'original-provider' ~/.omp/agent/config.yml | head -5
file ~/.omp/agent/config.yml  # Should be symlink again
```

## Gotchas

- **`hey re` builds from `~/.config/dotfiles`**, not the current worktree. Always apply edits to both.
- **`PI_SMOL_MODEL` is baked into the omp wrapper binary** via `makeWrapper --set`. Changing `smolModel` in Nix requires a rebuild to take effect. The config.yml `modelRoles.smol` is a lower-precedence fallback (precedence: `--smol` flag > `PI_SMOL_MODEL` > config.yml).
- **`dailyIntrospection.model` defaults to `openai-codex/gpt-5.6-sol:high`** in the module. Override it in the host config or the nightly introspection job will burn quota on the limited provider.
- **`home.file` with `force = true`** should overwrite the symlink on rebuild, but the home-manager activation step can silently fail to update `~/.omp/agent/config.yml`. Always verify after rebuilding.
- **Do not burn a banked reset** when the quota resets naturally within 24 hours. Save resets for heavy weeks where waiting would break flow.
- **`omp models <provider>` is the source of truth** for what's available. Never guess model IDs; always validate.
