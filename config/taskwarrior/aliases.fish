# Obsidian-Taskwarrior sync aliases
alias ots="obsidian-taskwarrior-sync"
alias ots-daily="obsidian-taskwarrior-sync daily"
alias ots-today="obsidian-taskwarrior-sync today"

# Original script aliases (for advanced use)
alias mtt_sync="~/repos/obsidian-taskwarrior-sync/mtt_sync.sh"
alias mtt_taskwarrior_to_md="~/repos/obsidian-taskwarrior-sync/mtt_taskwarrior_to_md.sh"
alias mtt_md_to_taskwarrior="~/repos/obsidian-taskwarrior-sync/mtt_md_to_taskwarrior.sh"
alias mtt_md_add_uuids="~/repos/obsidian-taskwarrior-sync/mtt_md_add_uuids.sh"

# Sync monitoring aliases
alias task-sync-logs="tail -f ~/.local/share/taskwarrior/sync.log"
alias task-sync-errors="tail -f ~/.local/share/taskwarrior/sync-error.log"
alias bugwarrior-logs="tail -f ~/.local/share/bugwarrior/pull.log"
alias bugwarrior-errors="tail -f ~/.local/share/bugwarrior/pull-error.log"
alias sync-status="launchctl list | grep com.user && echo 'Sync jobs status:' && ls -la ~/.local/share/taskwarrior/sync.log ~/.local/share/bugwarrior/pull.log 2>/dev/null"