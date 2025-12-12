# launchd Configuration

This directory contains launchd plists for automated task synchronization.

## Files

- `com.user.taskwarrior-sync.plist` - Syncs taskwarrior with TaskChampion server every 15 minutes

## Installation

These plists are automatically symlinked to `~/Library/LaunchAgents/` by the dotfiles setup.

To manually install:
```bash
ln -sf ~/.config/dotfiles/config/launchd/com.user.taskwarrior-sync.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.taskwarrior-sync.plist
```

## Management

- Check status: `launchctl list | grep com.user`
- Start manually: `launchctl start com.user.taskwarrior-sync`
- Stop: `launchctl unload ~/Library/LaunchAgents/com.user.*.plist`
- View logs: Use the aliases in `config/taskwarrior/aliases.zsh`

## Logs

- Taskwarrior: `~/.local/share/taskwarrior/sync.log` and `sync-error.log`
