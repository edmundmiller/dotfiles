#!/usr/bin/env bash
# Shared library for todo.sh Raycast script commands
# Source this at the top of each script: source "${BASH_SOURCE%/*}/_lib_todo_raycast.sh"

# Strict mode for safety
set -Eeuo pipefail
IFS=$' \n\t'

# Ensure Homebrew and common paths are available
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Global variables
TODO_CMD=""
TODO_CONFIG_LOADED=false

# Cleanup function for trap
cleanup() {
    # Add any cleanup logic here if needed (temp files, etc.)
    :
}

# Set up cleanup trap
trap cleanup EXIT

# Helper functions for consistent messaging
die() {
    echo "Error: $*" >&2
    exit 1
}

warn() {
    echo "Warning: $*" >&2
}

info() {
    echo "$*"
}

# Check if a command exists
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "$cmd is required but not found. Please install it."
    fi
}

# Resolve todo.sh path with fallbacks
resolve_todo_sh() {
    if [[ -n "${TODO_SH:-}" && -x "$TODO_SH" ]]; then
        TODO_CMD="$TODO_SH"
        return 0
    fi
    
    if command -v todo.sh >/dev/null 2>&1; then
        TODO_CMD="todo.sh"
        return 0
    fi
    
    for path in "/opt/homebrew/bin/todo.sh" "/usr/local/bin/todo.sh"; do
        if [[ -x "$path" ]]; then
            TODO_CMD="$path"
            return 0
        fi
    done
    
    die "todo.sh not found. Please install todo.txt-cli:
    brew install todo-txt
Or set TODO_SH environment variable to the full path."
}

# Load todo.txt configuration if available
load_config() {
    if [[ "$TODO_CONFIG_LOADED" == true ]]; then
        return 0
    fi
    
    # Try to source config files (suppress errors if they don't exist)
    for config_file in "$HOME/.todo/config" "$HOME/.todo.cfg" "${TODO_DIR:-}/todo.cfg"; do
        if [[ -r "$config_file" ]]; then
            # shellcheck disable=SC1090
            source "$config_file" 2>/dev/null || true
            TODO_CONFIG_LOADED=true
            break
        fi
    done
}

# Validate that input is a positive integer
validate_number() {
    local input="$1"
    local field_name="${2:-number}"
    
    if [[ ! "$input" =~ ^[0-9]+$ ]]; then
        die "$field_name must be a positive integer, got: '$input'"
    fi
    
    if [[ "$input" -eq 0 ]]; then
        die "$field_name must be greater than 0"
    fi
}

# Validate that input is not empty
validate_nonempty() {
    local input="$1"
    local field_name="${2:-input}"
    
    if [[ -z "$input" || "$input" =~ ^[[:space:]]*$ ]]; then
        die "$field_name cannot be empty"
    fi
}

# Check if a task number exists in the todo list
task_exists() {
    local task_num="$1"
    validate_number "$task_num" "task number"
    
    if ! "$TODO_CMD" ls | grep -q "^$task_num "; then
        die "Task #$task_num not found"
    fi
}

# Get task description for display
get_task_description() {
    local task_num="$1"
    validate_number "$task_num" "task number"
    
    "$TODO_CMD" ls | grep "^$task_num " | sed 's/^[0-9]* //' || die "Task #$task_num not found"
}

# Initialize the library
init_todo_raycast() {
    resolve_todo_sh
    load_config
    
    # Verify basic dependencies
    require_cmd "grep"
    require_cmd "sed"
}

# Auto-initialize when sourced
init_todo_raycast
