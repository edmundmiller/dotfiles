# jw help command

cmd_help() {
    cat <<'EOF'
jw - JJ Workspace management for parallel agents

USAGE:
    jw <command> [options]

COMMANDS:
    switch    Switch to a workspace (creates if -c flag used)
    list      List all workspaces with status  
    remove    Remove a workspace
    merge     Merge workspace changes to trunk
    sync      Sync workspace with trunk (rebase)
    help      Show this help message

SWITCH:
    jw switch <name>              Switch to existing workspace
    jw switch -c <name>           Create and switch to workspace
    jw switch -c -x claude <name> Create, switch, and start Claude
    jw switch -c -x code <name>   Create, switch, and open VS Code

LIST:
    jw list                       List workspaces with basic status
    jw list --full               Include ahead/behind counts
    jw list --json               Output as JSON

REMOVE:
    jw remove                     Remove current workspace
    jw remove <name>             Remove specific workspace
    jw remove -f <name>          Force remove (ignore uncommitted changes)

MERGE:
    jw merge                      Merge current workspace to trunk
    jw merge <name>              Merge specific workspace to trunk
    jw merge --squash            Squash all commits into one

SYNC:
    jw sync                       Sync current workspace with trunk
    jw sync <name>               Sync specific workspace with trunk

ALIASES (add to shell config):
    alias jws='jw switch'
    alias jwl='jw list'
    alias jwr='jw remove'
    alias jwm='jw merge'
    alias jwc='jw switch -c -x claude'  # Create + Claude

AGENT WORKFLOW:
    # Start multiple agents in parallel
    jw switch -c -x claude agent-1      # Terminal 1
    jw switch -c -x claude agent-2      # Terminal 2  
    jw switch -c -x opencode agent-3    # Terminal 3

    # Check status
    jw list --full

    # Merge completed work
    jw merge agent-1
    jw remove agent-1

CONFIGURATION:
    JW_WORKSPACE_PATH   Path pattern for workspaces
                        Default: ../{repo}--{name}
                        Supports: {repo}, {name}

EOF
}
