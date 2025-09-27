# launchd Configuration

This directory contains launchd plists for automated task synchronization.

## Files

- `com.user.taskwarrior-sync.plist` - Syncs taskwarrior with AWS TaskChampion every 15 minutes
- `com.user.bugwarrior-pull.plist` - Pulls tasks from Apple Reminders via bugwarrior every 30 minutes

## Installation

These plists are automatically symlinked to `~/Library/LaunchAgents/` by the dotfiles setup.

To manually install:
```bash
ln -sf ~/.config/dotfiles/config/launchd/com.user.taskwarrior-sync.plist ~/Library/LaunchAgents/
ln -sf ~/.config/dotfiles/config/launchd/com.user.bugwarrior-pull.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.taskwarrior-sync.plist
launchctl load ~/Library/LaunchAgents/com.user.bugwarrior-pull.plist
```

## Management

- Check status: `launchctl list | grep com.user`
- Start manually: `launchctl start com.user.taskwarrior-sync`
- Stop: `launchctl unload ~/Library/LaunchAgents/com.user.*.plist`
- View logs: Use the aliases in `config/taskwarrior/aliases.fish`

## Logs

- Taskwarrior: `~/.local/share/taskwarrior/sync.log` and `sync-error.log`  
- Bugwarrior: `~/.local/share/bugwarrior/pull.log` and `pull-error.log`