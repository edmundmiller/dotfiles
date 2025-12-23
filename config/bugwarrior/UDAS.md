# Bugwarrior UDA Management

## Per-Host System

Each host generates its own UDA file, both tracked in git. Taskrc includes both for union of all UDAs.

### Per-Host Files (Auto-generated)

| File | Host | Services |
|------|------|----------|
| `bugwarrior-udas-seqeratop.rc` | Seqeratop | Jira, GitHub |
| `bugwarrior-udas-mactraitorpro.rc` | MacTraitor-Pro | Linear, GitHub, Apple Reminders |

- **Location**: `config/taskwarrior/`
- **Tracked in git**: Yes
- **Regenerate when**: Adding/removing bugwarrior services on that host

### `bugwarrior-udas-custom.rc` (Manual Extensions)

- **Location**: `config/taskwarrior/bugwarrior-udas-custom.rc`
- **Tracked in git**: Yes
- **Contains**: Custom UDAs from `extra_fields` (e.g., `jirapriority`)

## Regenerating UDAs

### When to Regenerate

- Added a new bugwarrior service on this host
- Removed a service
- First-time setup on a new machine

### How to Regenerate

On **Seqeratop**:
```bash
bugwarrior uda > ~/.config/dotfiles/config/taskwarrior/bugwarrior-udas-seqeratop.rc
```

On **MacTraitor-Pro**:
```bash
bugwarrior uda > ~/.config/dotfiles/config/taskwarrior/bugwarrior-udas-mactraitorpro.rc
```

Then commit and push:
```bash
jj describe -m "chore(bugwarrior): regenerate UDAs for [hostname]"
jj git push
```

### Bootstrap Problem

If taskrc includes a UDA file that doesn't exist, bugwarrior will fail to generate UDAs.

**Solution**: Create empty placeholder first:
```bash
touch ~/.config/dotfiles/config/taskwarrior/bugwarrior-udas-<hostname>.rc
```

Then generate UDAs normally.

## Adding Custom UDAs

When using `extra_fields` in bugwarrior config, add UDA definition to `bugwarrior-udas-custom.rc`:

```toml
# In bugwarrior-work.toml
extra_fields = ["jirapriority:priority.name"]
```

```rc
# In bugwarrior-udas-custom.rc
uda.jirapriority.type=string
uda.jirapriority.label=JIRA Priority
```

## Troubleshooting

### "Could not read include file"

UDA file doesn't exist. See Bootstrap Problem above.

### "Service-defined UDAs exist" Warning

Regenerate the UDA file for this host.
