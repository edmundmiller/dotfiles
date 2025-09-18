#!/bin/bash
# Test fixtures and helper functions for integration tests

# Sample todo.txt content for testing
SAMPLE_TODO_CONTENT="Regular task without links
Fix bug in gh:owner/repo#123 and document the solution
Track issue jira:PROJ-456 until completion  
Multiple links: gh:nf-core/modules#2230 and jira:SD-789
(A) High priority task +project @context
x 2024-01-01 Completed task with gh:old/repo#999
Another regular task @home +personal
Edge case with gh:complex.name/repo_name#12345
Jira only: track jira:TEAM.SUB-999 progress
GitHub only: review gh:user/awesome-project#42"

# Create a test todo file with sample content
create_sample_todo_file() {
    echo "$SAMPLE_TODO_CONTENT" > "$TEST_TODO_FILE"
}

# Create a todo file with custom content
create_custom_todo_file() {
    echo "$1" > "$TEST_TODO_FILE"
}

# Set up Jira configuration via environment variable
setup_jira_env() {
    export JIRA_BASE_URL="$1"
}

# Set up Jira configuration via file
setup_jira_file() {
    echo "$1" > "$TEST_TODO_DIR/.jira_base_url"
}

# Clear all Jira configuration
clear_jira_config() {
    unset JIRA_BASE_URL
    unset OPEN_JIRA_BASE_URL
    rm -f "$TEST_TODO_DIR/.jira_base_url"
    rm -f "$HOME/.jira_base_url"
}

# Get the URLs that would be opened from the mock
get_opened_urls() {
    if [[ -f "$TEST_DIR/open_calls.log" ]]; then
        grep "MOCK_OPEN:" "$TEST_DIR/open_calls.log" | sed 's/MOCK_OPEN: //' | tr ' ' '\n' | grep -v '^$'
    fi
}

# Count how many URLs would be opened
count_opened_urls() {
    get_opened_urls | wc -l | tr -d ' '
}

# Check if a specific URL would be opened
url_was_opened() {
    local url="$1"
    get_opened_urls | grep -F "$url" > /dev/null
}

# Mock todo.sh list command for testing item number resolution
create_mock_todo_list() {
    local mock_todo_sh="$TEST_DIR/todo.sh"
    cat > "$mock_todo_sh" << EOF
#!/bin/bash
if [[ "\$1" == "-p" && "\$2" == "list" ]]; then
    # Mock the numbered list output
    cat "\$TODO_FILE" | nl -nln
else
    echo "Mock todo.sh called with: \$@"
fi
EOF
    chmod +x "$mock_todo_sh"
    export TODO_FULL_SH="$mock_todo_sh"
}

# Expected URLs for different test scenarios
EXPECTED_GITHUB_OWNER_REPO_123="https://github.com/owner/repo/issues/123"
EXPECTED_JIRA_PROJ_456_ATLASSIAN="https://company.atlassian.net/browse/PROJ-456"
EXPECTED_JIRA_PROJ_456_CUSTOM="https://jira.mycompany.com/browse/PROJ-456"
EXPECTED_GITHUB_NFCORE_MODULES_2230="https://github.com/nf-core/modules/issues/2230"
EXPECTED_JIRA_SD_789_ATLASSIAN="https://company.atlassian.net/browse/SD-789"

# Test data constants
readonly ITEM_WITH_GITHUB_ONLY=2         # "Fix bug in gh:owner/repo#123 and document the solution"
readonly ITEM_WITH_JIRA_ONLY=3           # "Track issue jira:PROJ-456 until completion"  
readonly ITEM_WITH_BOTH=4                # "Multiple links: gh:nf-core/modules#2230 and jira:SD-789"
readonly ITEM_WITHOUT_LINKS=1            # "Regular task without links"
readonly ITEM_NONEXISTENT=999            # Should not exist
