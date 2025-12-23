# Bugwarrior UDA Management

## Two-File System

### `bugwarrior-udas-auto.rc` (Union of All Services)

- **Location**: `config/taskwarrior/bugwarrior-udas-auto.rc`
- **Tracked in git**: Yes
- **Contains**: Union of all UDAs from all services across all hosts
- **Regenerate when**: Adding/removing bugwarrior service targets

### `bugwarrior-udas-custom.rc` (Manual Extensions)

- **Location**: `config/taskwarrior/bugwarrior-udas-custom.rc`
- **Tracked in git**: Yes
- **Contains**: Custom UDAs from `extra_fields` (e.g., `jirapriority`)

## Current Services & UDAs

| Service         | Host           | Examples                                       |
| --------------- | -------------- | ---------------------------------------------- |
| Apple Reminders | Both           | `applereminderstitle`, `appleremindersduedate` |
| Linear          | Both           | `linearidentifier`, `linearstatus`             |
| GitHub          | Both           | `githuburl`, `githubnumber`, `githubtype`      |
| Jira            | Seqeratop only | `jiraurl`, `jirasummary`, `jirastatus`         |

## Regenerating UDAs

### When to Regenerate

- Added a new bugwarrior service
- Removed a service
- First-time setup on Seqeratop (to capture Jira UDAs)

### How to Regenerate

Run on **Seqeratop** (has all services including Jira):

```bash
bugwarrior-regen-udas
```

Or manually:

```bash
bugwarrior uda > ~/.config/dotfiles/config/taskwarrior/bugwarrior-udas-auto.rc
jj describe -m "chore(bugwarrior): regenerate UDAs after adding [service]"
jj git push
```

On **MacTraitor-Pro**, pull the updates:

```bash
jj git fetch && jj new main@origin
```

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

### Missing Jira UDAs

Regenerate on Seqeratop which has Jira configured.

### "Service-defined UDAs exist" Warning

Regenerate the auto file after adding new services.
