# JJ Configuration

Jujutsu (jj) configuration managed via nix-darwin.

## Merge Tools

| Tool            | Command                         | Use Case                                 |
| --------------- | ------------------------------- | ---------------------------------------- |
| `diffconflicts` | `jj resolve`                    | Default - nvim-based conflict resolution |
| `beads-merge`   | `jj resolve --tool=beads-merge` | For `.beads/` files only                 |

### Beads Merge Tool

For conflicts in `.beads/issues.jsonl`, use:

```bash
jj resolve --tool=beads-merge
```

This uses `bd merge` which performs field-level 3-way merging instead of line-based, preserving concurrent updates to different fields of the same issue.

## Shell Aliases (aliases.zsh)

| Alias     | Command         | Purpose                              |
| --------- | --------------- | ------------------------------------ |
| `jn`      | `jj new`        | Start new work                       |
| `js`      | `jj squash`     | Squash changes into parent           |
| `jd`      | `jj describe`   | Describe current commit              |
| `je`      | `jj edit`       | Edit a commit                        |
| `jp`      | `jj prev`       | Go to previous commit                |
| `jnx`     | `jj next`       | Go to next commit                    |
| `jst`     | `jj status`     | Show status                          |
| `jdiff`   | `jj diff`       | Show differences                     |
| `jshow`   | `jj show`       | Show commit details                  |
| `jmdiff`  | `jj mdiff`      | Diff from trunk (PR preview)         |
| `jres`    | `jj restore`    | Discard changes (safer than abandon) |
| `jresi`   | `jj restore -i` | Interactively discard parts          |
| `jr`      | `jj rebase`     | Rebase commits                       |
| `jb`      | `jj bookmark`   | Manage bookmarks                     |
| `jsync`   | `jj sync`       | Fetch all remotes                    |
| `jevolve` | `jj evolve`     | Rebase current onto trunk            |
| `jpullup` | `jj pullup`     | Pull all mutable commits onto trunk  |

### Log Variants

| Alias | Template     | Use Case                          |
| ----- | ------------ | --------------------------------- |
| `jl`  | ai_log       | Default (AI-optimized, shows tip) |
| `jlh` | human_log    | Human-friendly                    |
| `jlc` | credits_roll | Visual/rich formatting            |

### Workflow Functions

| Function        | Purpose                               |
| --------------- | ------------------------------------- |
| `jnew [msg]`    | Describe and create new commit        |
| `jsquash [msg]` | Quick squash with optional message    |
| `jclean`        | Tidy empty commits + show status      |
| `jwork`         | Show only your active work            |
| `jback`         | Abandon empty current, go to previous |
| `jnd`           | Open diff in neovim (PR preview)      |

## JJ Aliases (config.toml)

Key workflow aliases defined in jj itself:

| Alias    | Command                                      | Purpose                            |
| -------- | -------------------------------------------- | ---------------------------------- |
| `sync`   | `git fetch --all-remotes`                    | Update from all remotes            |
| `evolve` | `rebase --skip-emptied -d trunk()`           | Rebase current onto trunk          |
| `pullup` | `rebase -s "mine() & ~::trunk()" -d trunk()` | Rebase ALL your commits onto trunk |
| `mdiff`  | `diff --from trunk()`                        | What will be in your PR            |
| `tug`    | Move closest bookmark to current             | Prep for pushing                   |
| `tidy`   | Abandon empty+undescribed commits            | Cleanup                            |

## Key Workflows

### Restore (jres/jresi)

`restore` is underrated compared to `abandon`. Use cases:

```bash
jj restore              # Discard all changes (safer than abandon)
jj restore -i           # Interactively discard parts (e.g., debug code)
jj restore -f main path/to/file  # Restore specific file from main
```

### Sync & Evolve Workflow (jsync/jevolve/jpullup)

```bash
jsync      # Fetch all remotes
jevolve    # Rebase current commit onto trunk
jpullup    # Rebase ALL your straggler commits onto trunk at once
```

`pullup` saves time - instead of rebasing commits one by one, it moves all your mutable work onto trunk in a single command.

### PR Preview (jmdiff)

```bash
jmdiff     # Show diff from trunk - exactly what will be in your PR
```

Useful before pushing to review what you're actually submitting.

## Configuration Files

- `config.toml` - Main JJ configuration
- `conf.d/*.toml` - Per-context settings (work, nf-core, etc.)
- `aliases.zsh` - Shell aliases (sourced by zsh)

## References

- [More Commands in the JJ Toolbox](https://willhbr.net/2025/11/22/more-commands-in-the-jj-toolbox/) - Inspiration for restore/evolve/pullup aliases
