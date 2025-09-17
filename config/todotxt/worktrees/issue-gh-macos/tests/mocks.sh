#!/bin/bash
# Mock utilities for testing todo.txt actions
# Provides mocked versions of external commands to ensure deterministic testing

# Mock state variables
MOCK_GH_AUTH_STATUS=0
MOCK_GH_AVAILABLE=1
MOCK_OSASCRIPT_CALLED=""
MOCK_OPEN_CALLED=""
MOCK_CURL_RESPONSE=""
MOCK_CURL_EXIT_CODE=0
MOCK_PYTHON_AVAILABLE=1
MOCK_GITHUB_TOKEN="mock_token_12345"

# Reset all mocks to default state
reset_mocks() {
    MOCK_GH_AUTH_STATUS=0
    MOCK_GH_AVAILABLE=1
    MOCK_OSASCRIPT_CALLED=""
    MOCK_OPEN_CALLED=""
    MOCK_CURL_RESPONSE=""
    MOCK_CURL_EXIT_CODE=0
    MOCK_PYTHON_AVAILABLE=1
    MOCK_GITHUB_TOKEN="mock_token_12345"
    
    unset MOCK_GH_ISSUE_VIEW_CALLS
    unset MOCK_GH_ISSUE_CLOSE_CALLS
    unset MOCK_GH_ISSUE_CREATE_CALLS
    declare -ga MOCK_GH_ISSUE_VIEW_CALLS=()
    declare -ga MOCK_GH_ISSUE_CLOSE_CALLS=()
    declare -ga MOCK_GH_ISSUE_CREATE_CALLS=()
}

# Mock GitHub CLI (gh)
gh() {
    if [[ $MOCK_GH_AVAILABLE -eq 0 ]]; then
        echo "gh: command not found" >&2
        return 127
    fi
    
    case "$1" in
        "auth")
            case "$2" in
                "status")
                    if [[ $MOCK_GH_AUTH_STATUS -eq 0 ]]; then
                        cat << EOF
github.com
  ✓ Logged in to github.com account testuser (keyring)
  - Active account: true
  - Git operations protocol: ssh
  - Token: gho_************************************
  - Token scopes: 'codespace', 'gist', 'project', 'read:org', 'repo', 'workflow'
EOF
                        return 0
                    else
                        echo "github.com: authentication required" >&2
                        return 1
                    fi
                    ;;
                "token")
                    if [[ $MOCK_GH_AUTH_STATUS -eq 0 ]]; then
                        echo "$MOCK_GITHUB_TOKEN"
                        return 0
                    else
                        echo "gh: authentication required" >&2
                        return 1
                    fi
                    ;;
            esac
            ;;
        "issue")
            case "$2" in
                "view")
                    local issue_num="$3"
                    local repo=""
                    # Parse -R flag
                    if [[ "$4" == "-R" ]]; then
                        repo="$5"
                    fi
                    if [[ "$6" == "--web" ]]; then
                        MOCK_GH_ISSUE_VIEW_CALLS+=("$issue_num $repo --web")
                        return 0
                    else
                        MOCK_GH_ISSUE_VIEW_CALLS+=("$issue_num $repo")
                        echo "Mock issue view for #$issue_num in $repo"
                        return 0
                    fi
                    ;;
                "close")
                    local issue_num="$3"
                    local repo=""
                    if [[ "$4" == "-R" ]]; then
                        repo="$5"
                    fi
                    MOCK_GH_ISSUE_CLOSE_CALLS+=("$issue_num $repo")
                    return 0
                    ;;
                "create")
                    local repo=""
                    local title=""
                    local body=""
                    # Parse flags
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -R) repo="$2"; shift 2 ;;
                            -t) title="$2"; shift 2 ;;
                            -b) body="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    MOCK_GH_ISSUE_CREATE_CALLS+=("$repo: $title - $body")
                    echo "https://github.com/$repo/issues/1"
                    return 0
                    ;;
            esac
            ;;
        "api")
            case "$2" in
                "user")
                    cat << 'EOF'
{
  "login": "testuser",
  "id": 12345,
  "name": "Test User"
}
EOF
                    return 0
                    ;;
            esac
            ;;
    esac
    
    # Default fallback
    echo "Mock gh called with: $*" >&2
    return 0
}

# Mock osascript (macOS notifications)
osascript() {
    MOCK_OSASCRIPT_CALLED="$*"
    return 0
}

# Mock open (macOS URL opening)
open() {
    MOCK_OPEN_CALLED="$*"
    return 0
}

# Mock curl
curl() {
    if [[ $MOCK_CURL_EXIT_CODE -ne 0 ]]; then
        return $MOCK_CURL_EXIT_CODE
    fi
    
    if [[ -n "$MOCK_CURL_RESPONSE" ]]; then
        echo "$MOCK_CURL_RESPONSE"
    fi
    
    return 0
}

# Mock python3
python3() {
    if [[ $MOCK_PYTHON_AVAILABLE -eq 0 ]]; then
        echo "python3: command not found" >&2
        return 127
    fi
    
    case "$1" in
        "--version")
            echo "Python 3.12.0"
            return 0
            ;;
        *)
            echo "Mock python3 called with: $*" >&2
            return 0
            ;;
    esac
}

# Mock uname (for OS detection)
uname() {
    case "$1" in
        "")
            echo "Darwin"  # Default to macOS for most tests
            ;;
        *)
            echo "Darwin"
            ;;
    esac
}

# Mock command (for checking if commands exist)
command() {
    if [[ "$1" == "-v" ]]; then
        case "$2" in
            "gh")
                if [[ $MOCK_GH_AVAILABLE -eq 1 ]]; then
                    echo "/usr/local/bin/gh"
                    return 0
                else
                    return 1
                fi
                ;;
            "python3")
                if [[ $MOCK_PYTHON_AVAILABLE -eq 1 ]]; then
                    echo "/usr/bin/python3"
                    return 0
                else
                    return 1
                fi
                ;;
            *)
                echo "/usr/bin/$2"
                return 0
                ;;
        esac
    fi
    
    # Default behavior
    /usr/bin/command "$@"
}

# Mock todo.sh (for testing issue action's integration)
todo_sh_mock() {
    case "$1" in
        "show")
            local item_num="$2"
            echo "Mock todo item $item_num content"
            return 0
            ;;
        "done")
            local item_num="$2"
            echo "$item_num x $(date '+%Y-%m-%d') Mock todo item $item_num content"
            return 0
            ;;
        *)
            echo "Mock todo.sh called with: $*" >&2
            return 0
            ;;
    esac
}

# Helper functions to check mock calls
get_gh_issue_view_calls() {
    printf '%s\n' "${MOCK_GH_ISSUE_VIEW_CALLS[@]}"
}

get_gh_issue_close_calls() {
    printf '%s\n' "${MOCK_GH_ISSUE_CLOSE_CALLS[@]}"
}

get_gh_issue_create_calls() {
    printf '%s\n' "${MOCK_GH_ISSUE_CREATE_CALLS[@]}"
}

count_gh_calls() {
    local call_type="$1"
    case "$call_type" in
        "view") echo "${#MOCK_GH_ISSUE_VIEW_CALLS[@]}" ;;
        "close") echo "${#MOCK_GH_ISSUE_CLOSE_CALLS[@]}" ;;
        "create") echo "${#MOCK_GH_ISSUE_CREATE_CALLS[@]}" ;;
        *) echo "0" ;;
    esac
}

# Mock scenarios
mock_scenario_gh_unavailable() {
    MOCK_GH_AVAILABLE=0
}

mock_scenario_gh_unauthenticated() {
    MOCK_GH_AVAILABLE=1
    MOCK_GH_AUTH_STATUS=1
}

mock_scenario_gh_authenticated() {
    MOCK_GH_AVAILABLE=1
    MOCK_GH_AUTH_STATUS=0
}

mock_scenario_python_unavailable() {
    MOCK_PYTHON_AVAILABLE=0
}

mock_scenario_curl_failure() {
    MOCK_CURL_EXIT_CODE=1
    MOCK_CURL_RESPONSE="curl: (7) Failed to connect"
}

# Set up Linux environment for cross-platform testing
mock_linux_environment() {
    uname() {
        echo "Linux"
    }
}

# Initialize mocks
reset_mocks
