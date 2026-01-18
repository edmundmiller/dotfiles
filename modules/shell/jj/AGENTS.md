# JJ (Jujutsu) Module - Agent Documentation

## Purpose
Configures jj (Jujutsu VCS) with custom templates, aliases, and integrations.

## AI-First Log System

**Default `jj log` is optimized for AI agents** - token-efficient, parseable output.

### Templates

| Template | Command | Purpose |
|----------|---------|---------|
| `ai_log` | `jj log` (default) | AI-optimized: minimal tokens, structured |
| `human_log` | `jj lh` | Clean readability for humans |
| `credits_roll` | `jj lc` | Rich visual formatting with diff stats |

### Revset Filter

Default revset shows only YOUR unmerged work (not all branches):
```
@ | ancestors(trunk()..(visible_heads() & mine()), 2) | trunk()
```

Override when needed:
- `jj la-all` - See all commits
- `jj la-team` - See others' commits only

### AI Log Format

```
xyzvwmqo 12a3bc45 [author] 2h ago feature-branch Add new feature
```

Fields: `change_id commit_id [author_if_not_me] relative_time flags bookmarks description`

Flags: `∅` empty, `✖` conflict, `◆` immutable

### Token Savings

Measured on 10 commits:

| Metric | Old (verbose) | New (ai_log) | Reduction |
|--------|---------------|--------------|-----------|
| Bytes  | 4107          | 806          | **80%**   |
| Lines  | 88            | 14           | **84%**   |

The `mine()` revset filter provides additional savings by showing only ~5-10 commits
(your unmerged work) instead of potentially 1000s of commits in repos with many branches.

## External Dependencies

### Credits Roll Templates
- **Source:** https://github.com/YPares/jj.conf.d
- **Fetched via:** `pkgs.fetchurl` in `default.nix`
- **Purpose:** Rich log formatting with diff stats, width calculations, pin markers
- **Key alias:** `format_short_id(id)` - takes ChangeId, NOT Commit

## Config Structure

```
~/.config/jj/
├── config.toml           # Main config (from config/jj/config.toml)
└── conf.d/
    ├── credits_roll.toml # Fetched from GitHub (YPares/jj.conf.d)
    ├── fix.toml          # Code formatters (jj fix)
    ├── fg.toml           # UTD academic repos
    ├── nfcore.toml       # nf-core repos
    └── seqera.toml       # Work repos
```

## Template System Gotchas

### Type Signatures Matter

JJ template aliases are strongly typed. Common mistake:

```toml
# WRONG - id is already a ChangeId, don't call .change_id() on it
"format_short_change_id(id)" = 'id.change_id().shortest(4)'

# CORRECT - id is a ChangeId, call .shortest() directly
"format_short_id(id)" = 'id.shortest(config("width").as_integer()/20)'
```

### Alias Name Conflicts

The `credits_roll.toml` from upstream defines its own aliases. Don't redefine them
in `config.toml` with different signatures or you'll get type errors.

**Credits roll provides:**
- `format_short_id(id)` - ChangeId formatting
- `credits_roll_w(width, max_summary_lines, statted_revset)` - Main template
- `credits_roll(max_summary_lines, statted_revset)` - Wrapper with auto-width

**Don't define in config.toml:**
- `format_short_change_id` - conflicts with credits_roll

### Deprecated Aliases

These jj built-in aliases no longer exist:
- `format_short_change_id_with_hidden_and_divergent_info` - removed
- `format_short_change_id_with_change_offset` - removed

Use direct method calls instead:
```toml
self.change_id().shortest(4)  # Instead of format_short_change_id_with_*
```

## Deprecated Config Settings

Use the new format:
```toml
# OLD (deprecated)
[git]
auto-local-bookmark = true

# NEW (correct)
[remotes.origin]
auto-track-bookmarks = '*'
```

## Key Aliases

| Category | Aliases | Purpose |
|----------|---------|---------|
| Navigation | `p`, `n` | prev/next commit |
| Viewing | `la` (default), `lh`, `lc`, `lg`, `lm`, `pp` | Various log formats |
| Viewing (extended) | `la-all`, `la-team` | Override mine() filter |
| Cleanup | `cleanup`, `tidy`, `abandon-empty` | Remove empty commits |
| Workflow | `wip`, `tug`, `retrunk`, `sync` | Common operations |
| AI | `aid`, `aide`, `ai-desc` | AI commit messages |
| GitHub | `spr`, `nd` | Stacked PRs, diff preview |

## Related Files

- `config/jj/config.toml` - Main config (aliases, UI, signing, merge-tools)
- `config/jj/conf.d/*.toml` - Modular configs (work repos, fix tools)
- `config/jj/aliases.zsh` - Shell aliases
- `config/jjui/config.toml` - JJUI TUI keybindings (Catppuccin theme, power user commands)
- `config/tmux/open-git-tui.sh` - Smart launcher (jjui for jj repos, gitu for git)

## Nix Module Options

```nix
modules.shell.jj.enable = true;  # Enable jj with all configs
```

## Troubleshooting

### "Method doesn't exist for type ChangeId"
Check template aliases for signature mismatches. Likely calling `.change_id()` on
something that's already a ChangeId.

### "Deprecated config" warnings
Search for old setting names and update to new format. See "Deprecated Config
Settings" above.

### Config not updating after rebuild
Files are managed via home-manager's `xdg.configFile`. Run `hey rebuild` and
restart terminal/jj to pick up changes.
