#!/bin/bash
# Unit tests for URL parsing in the open action

# Source the test framework
source "$(dirname "$0")/test_framework.sh"

# Test GitHub URL parsing
test_github_basic_parsing() {
    local input="Check out this issue gh:owner/repo#123 for details"
    
    # Extract GitHub tokens using the same regex as the script
    local tokens=$(echo "$input" | grep -oE 'gh:[A-Za-z0-9._-]+/[A-Za-z0-9._-]+#[0-9]+' | sort -u)
    
    assert_equals "gh:owner/repo#123" "$tokens" "GitHub token extracted correctly"
    
    # Test URL generation
    if [[ "$tokens" =~ ^gh:([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)#([0-9]+)$ ]]; then
        local owner="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]}"
        local issue="${BASH_REMATCH[3]}"
        local url="https://github.com/$owner/$repo/issues/$issue"
        
        assert_equals "https://github.com/owner/repo/issues/123" "$url" "GitHub URL generated correctly"
    else
        assert_equals "match" "no-match" "GitHub regex should match"
    fi
}

test_github_complex_names() {
    local input="Bug in gh:nf-core/modules#2230 and also gh:user.name/repo_name#999"
    
    local tokens=$(echo "$input" | grep -oE 'gh:[A-Za-z0-9._-]+/[A-Za-z0-9._-]+#[0-9]+' | sort -u)
    local expected="gh:nf-core/modules#2230
gh:user.name/repo_name#999"
    
    assert_equals "$expected" "$tokens" "Multiple GitHub tokens with complex names extracted"
}

test_github_edge_cases() {
    # Test various edge cases that should NOT match
    local invalid_cases=(
        "gh:owner#123"          # Missing repo
        "gh:owner/#123"         # Empty repo
        "gh:owner/repo"         # Missing issue
        "gh:owner/repo#"        # Empty issue
        "gh:/repo#123"          # Empty owner
        "gh:owner/repo#abc"     # Non-numeric issue
        "github:owner/repo#123" # Wrong prefix
    )
    
    for case in "${invalid_cases[@]}"; do
        local tokens=$(echo "$case" | grep -oE 'gh:[A-Za-z0-9._-]+/[A-Za-z0-9._-]+#[0-9]+' | sort -u)
        assert_equals "" "$tokens" "Invalid case should not match: $case"
    done
}

test_jira_basic_parsing() {
    local input="Track this in jira:PROJ-123 and also jira:SD-456"
    
    local tokens=$(echo "$input" | grep -oE 'jira:[A-Za-z0-9._-]+-[0-9]+' | sort -u)
    local expected="jira:PROJ-123
jira:SD-456"
    
    assert_equals "$expected" "$tokens" "Jira tokens extracted correctly"
    
    # Test URL generation with base
    local jira_base="https://company.atlassian.net"
    local first_token="jira:PROJ-123"
    
    if [[ "$first_token" =~ ^jira:([A-Za-z0-9._-]+-[0-9]+)$ ]]; then
        local ticket="${BASH_REMATCH[1]}"
        local url="$jira_base/browse/$ticket"
        
        assert_equals "https://company.atlassian.net/browse/PROJ-123" "$url" "Jira URL generated correctly"
    else
        assert_equals "match" "no-match" "Jira regex should match"
    fi
}

test_jira_complex_names() {
    local input="Issues: jira:PROJECT_NAME-123 and jira:TEAM.SUBTEAM-999"
    
    local tokens=$(echo "$input" | grep -oE 'jira:[A-Za-z0-9._-]+-[0-9]+' | sort -u)
    local expected="jira:PROJECT_NAME-123
jira:TEAM.SUBTEAM-999"
    
    assert_equals "$expected" "$tokens" "Jira tokens with complex names extracted"
}

test_jira_edge_cases() {
    # Test various edge cases that should NOT match
    local invalid_cases=(
        "jira:PROJ"         # Missing number
        "jira:PROJ-"        # Empty number
        "jira:-123"         # Empty project
        "jira:PROJ_123"     # Underscore instead of dash
        "jira:PROJ#123"     # Hash instead of dash
        "JIRA:PROJ-123"     # Wrong case
    )
    
    for case in "${invalid_cases[@]}"; do
        local tokens=$(echo "$case" | grep -oE 'jira:[A-Za-z0-9._-]+-[0-9]+' | sort -u)
        assert_equals "" "$tokens" "Invalid case should not match: $case"
    done
}

test_mixed_tokens() {
    local input="Fix gh:owner/repo#123 and track in jira:PROJ-456"
    
    local gh_tokens=$(echo "$input" | grep -oE 'gh:[A-Za-z0-9._-]+/[A-Za-z0-9._-]+#[0-9]+' | sort -u)
    local jira_tokens=$(echo "$input" | grep -oE 'jira:[A-Za-z0-9._-]+-[0-9]+' | sort -u)
    
    assert_equals "gh:owner/repo#123" "$gh_tokens" "GitHub token found in mixed input"
    assert_equals "jira:PROJ-456" "$jira_tokens" "Jira token found in mixed input"
}

test_no_tokens() {
    local input="This is a regular todo item with no special tokens"
    
    local gh_tokens=$(echo "$input" | grep -oE 'gh:[A-Za-z0-9._-]+/[A-Za-z0-9._-]+#[0-9]+' | sort -u)
    local jira_tokens=$(echo "$input" | grep -oE 'jira:[A-Za-z0-9._-]+-[0-9]+' | sort -u)
    
    assert_equals "" "$gh_tokens" "No GitHub tokens in regular text"
    assert_equals "" "$jira_tokens" "No Jira tokens in regular text"
}

test_duplicate_tokens() {
    local input="Check gh:owner/repo#123 and also check gh:owner/repo#123 again"
    
    local tokens=$(echo "$input" | grep -oE 'gh:[A-Za-z0-9._-]+/[A-Za-z0-9._-]+#[0-9]+' | sort -u)
    
    assert_equals "gh:owner/repo#123" "$tokens" "Duplicate tokens should be deduplicated"
    
    # Count occurrences to ensure sort -u worked
    local count=$(echo "$tokens" | wc -l | tr -d ' ')
    assert_equals "1" "$count" "Should have exactly one unique token"
}

# Run all tests
main() {
    echo "URL Parsing Unit Tests"
    echo "======================"
    
    run_test test_github_basic_parsing
    run_test test_github_complex_names
    run_test test_github_edge_cases
    run_test test_jira_basic_parsing
    run_test test_jira_complex_names
    run_test test_jira_edge_cases
    run_test test_mixed_tokens
    run_test test_no_tokens
    run_test test_duplicate_tokens
    
    print_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
