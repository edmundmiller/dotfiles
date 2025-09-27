# Obsidian-Taskwarrior Sync Integration

This dotfiles configuration includes seamless integration between Obsidian and Taskwarrior for task management.

## Overview

The integration allows you to:
- ✅ Sync tasks from Obsidian markdown files to Taskwarrior
- ✅ Automatic bidirectional sync via Taskwarrior hooks
- ✅ Preserve your existing task IDs (🆔 format)
- ✅ Handle spaces in file paths correctly
- ✅ Easy command-line interface

## Installation

### Fresh Install
```bash
install-obsidian-taskwarrior-sync
```

### Manual Install
If you need to set this up on a new machine:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/nbossard/obsidian-taskwarrior-sync.git ~/repos/obsidian-taskwarrior-sync
   ```

2. **Install the hook:**
   ```bash
   install-obsidian-taskwarrior-sync
   ```

3. **Source the aliases:**
   ```bash
   source ~/.config/dotfiles/config/taskwarrior/aliases.fish
   ```

## Usage

### Quick Commands
```bash
# Sync all daily notes
ots-daily

# Sync just today's note  
ots-today

# General sync command
ots help
```

### Detailed Commands
```bash
# Sync specific file
obsidian-taskwarrior-sync file "periodic/daily/2025-07-23.md"

# Sync project folder
obsidian-taskwarrior-sync project "1-Projects/PhD Dissertation"

# Sync all daily notes
obsidian-taskwarrior-sync daily

# Sync today's daily note
obsidian-taskwarrior-sync today

# Sync entire vault (careful!)
obsidian-taskwarrior-sync all
```

### Direct Script Access
For advanced users, the original scripts are also aliased:
```bash
mtt_sync                    # Main sync script
mtt_taskwarrior_to_md      # Export tasks to markdown
mtt_md_to_taskwarrior      # Import markdown tasks
mtt_md_add_uuids           # Add UUIDs to tasks
```

## How It Works

### Task Format
Your Obsidian tasks can use your existing format:
```markdown
- [ ] Do something important 🆔 abc123
```

The sync process automatically adds UUID tracking:
```markdown
- [ ] Do something important 🆔 abc123 [id:: uuid-here]
```

### Bidirectional Sync
1. **Obsidian → Taskwarrior**: Run sync commands to import tasks
2. **Taskwarrior → Obsidian**: Automatic via hook when you modify tasks

### Project Assignment
- Tasks are assigned to Taskwarrior projects based on the sync command used
- `ots-daily` → `daily` project
- `ots-today` → `today` project  
- `ots file` → `file` project
- Custom projects can be specified

## Configuration

### Paths
- **Obsidian Vault**: `~/Documents/Obsidian Vault`
- **Sync Scripts**: `~/repos/obsidian-taskwarrior-sync/`
- **Taskwarrior Data**: `~/Library/Mobile Documents/iCloud~com~mav~taskchamp/Documents/task`

### Hook Location
The Taskwarrior hook is installed at:
```
~/Library/Mobile Documents/iCloud~com~mav~taskchamp/Documents/task/hooks/on-modify.obsidian-sync
```

## Troubleshooting

### Check Requirements
```bash
~/repos/obsidian-taskwarrior-sync/mtt_check_requirements.sh
```

### Reinstall Hook
```bash
install-obsidian-taskwarrior-sync
```

### Manual Hook Test
```bash
# Complete a task and verify the markdown file updates
task add "Test task from CLI"
task list
task <id> done
# Check that the corresponding Obsidian file was updated
```

## Files in This Integration

- `bin/obsidian-taskwarrior-sync` - Main command-line interface
- `bin/install-obsidian-taskwarrior-sync` - Installation script
- `config/taskwarrior/aliases.fish` - Fish shell aliases
- `docs/obsidian-taskwarrior-sync.md` - This documentation
- Taskwarrior hook at data location

## Dependencies

- [Taskwarrior](https://taskwarrior.org/) v3+
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- `sed`, `awk` (standard Unix tools)
- [obsidian-taskwarrior-sync](https://github.com/nbossard/obsidian-taskwarrior-sync) repository

## Notes

- Tasks maintain their original 🆔 format alongside UUID tracking
- The hook only activates when tasks are modified in Taskwarrior
- Sync is uni-directional from Obsidian to Taskwarrior (import only)
- Updates from Taskwarrior to Obsidian are bi-directional via the hook