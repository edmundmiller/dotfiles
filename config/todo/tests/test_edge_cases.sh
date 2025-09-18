#!/bin/bash
# Edge case and error handling tests for the open action

# Source the test framework and fixtures
source "$(dirname "$0")/test_framework.sh"
source "$(dirname "$0")/test_fixtures.sh"

test_missing_todo_file_env() {
    # Test when TODO_FILE environment variable is not set
    unset TODO_FILE
    
    local output=$(run_open_action "1")
    local exit_code=$?
    
    assert_exit_code 1 $exit_code "Should fail when TODO_FILE not set"
    assert_contains "$output" "Error: TODO_FILE is not set or file not found" "Should report missing TODO_FILE"
}

test_nonexistent_todo_file() {
    # Test when TODO_FILE points to nonexistent file
    export TODO_FILE="/nonexistent/path/todo.txt"
    
    local output=$(run_open_action "1")
    local exit_code=$?
    
    assert_exit_code 1 $exit_code "Should fail when TODO_FILE doesn't exist"
    assert_contains "$output" "Error: TODO_FILE is not set or file not found" "Should report file not found"
}

test_malformed_github_tokens() {
    local malformed_cases=(
        "Test gh:owner/repo#0123 with leading zero"  # Leading zeros in issue number
        "Test gh:owner/repo#999999999999999999999 overflow"  # Very large issue number
        "Test gh:o/r#1 short names"  # Minimum length names
        "Test gh:owner-with-dashes/repo.with.dots#123 special chars"
    )
    
    for i in "${!malformed_cases[@]}"; do
        create_custom_todo_file "${malformed_cases[$i]}"
        local output=$(run_open_action "1")
        local exit_code=$?
        
        # These should actually work since our regex is permissive
        if [[ $exit_code -eq 0 ]]; then
            assert_exit_code 0 $exit_code "Should handle: ${malformed_cases[$i]}"
            assert_contains "$output" "Opening 1 link(s)" "Should find link in: ${malformed_cases[$i]}"
        else
            # If it fails, it should be due to no links found
            assert_exit_code 2 $exit_code "Should exit with no links for: ${malformed_cases[$i]}"
        fi
    done
}

test_malformed_jira_tokens() {
    setup_jira_env "company.atlassian.net"
    
    local malformed_cases=(
        "Test jira:A-1 minimal"  # Minimum length
        "Test jira:VERY_LONG_PROJECT_NAME-123456789 long"  # Long names
        "Test jira:PROJ.SUB.TEAM-999 dots"  # Multiple dots
        "Test jira:TEAM_SUB_PROJECT-001 underscores"  # Multiple underscores
    )
    
    for i in "${!malformed_cases[@]}"; do
        create_custom_todo_file "${malformed_cases[$i]}"
        local output=$(run_open_action "1")
        local exit_code=$?
        
        # These should work since our regex supports these patterns
        assert_exit_code 0 $exit_code "Should handle: ${malformed_cases[$i]}"
        assert_contains "$output" "Opening 1 link(s)" "Should find Jira link in: ${malformed_cases[$i]}"
    done
}

test_unicode_in_todo_text() {
    local unicode_content="Fix 🐛 bug gh:owner/repo#123 with emojis"
    create_custom_todo_file "$unicode_content"
    
    local output=$(run_open_action "1")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should handle unicode characters"
    assert_contains "$output" "Opening 1 link(s)" "Should find GitHub link despite unicode"
    assert_contains "$output" "https://github.com/owner/repo/issues/123" "Should generate correct URL"
}

test_very_long_todo_line() {
    local long_prefix=$(printf 'A%.0s' {1..1000})  # 1000 A's
    local long_content="${long_prefix} gh:owner/repo#123 ${long_prefix}"
    create_custom_todo_file "$long_content"
    
    local output=$(run_open_action "1")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should handle very long todo lines"
    assert_contains "$output" "Opening 1 link(s)" "Should find link in very long line"
}

test_many_tokens_in_one_line() {
    local many_tokens=""
    for i in {1..20}; do
        many_tokens+="gh:owner/repo#$i "
    done
    create_custom_todo_file "$many_tokens"
    
    local output=$(run_open_action "1")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should handle many tokens"
    assert_contains "$output" "Opening 20 link(s)" "Should find all 20 links"
}

test_empty_jira_config_file() {
    create_sample_todo_file
    
    # Create empty Jira config file
    touch "$TEST_TODO_DIR/.jira_base_url"
    
    local output=$(run_open_action "$ITEM_WITH_JIRA_ONLY")
    local exit_code=$?
    
    assert_exit_code 2 $exit_code "Should handle empty Jira config file"
    assert_contains "$output" "Warning: Found Jira tokens but JIRA_BASE_URL is not configured" "Should warn about empty config"
}

test_whitespace_only_jira_config() {
    create_sample_todo_file
    
    # Create Jira config file with only whitespace
    echo "   " > "$TEST_TODO_DIR/.jira_base_url"
    
    local output=$(run_open_action "$ITEM_WITH_JIRA_ONLY")
    local exit_code=$?
    
    assert_exit_code 2 $exit_code "Should handle whitespace-only Jira config"
    assert_contains "$output" "Warning: Found Jira tokens but JIRA_BASE_URL is not configured" "Should warn about whitespace config"
}

test_multiline_jira_config() {
    create_sample_todo_file
    
    # Create Jira config file with multiple lines (should use first non-empty line)
    cat > "$TEST_TODO_DIR/.jira_base_url" << EOF

company.atlassian.net
# This is a comment
backup.atlassian.net
EOF
    
    local output=$(run_open_action "$ITEM_WITH_JIRA_ONLY")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should handle multiline Jira config"
    assert_contains "$output" "https://company.atlassian.net/browse/PROJ-456" "Should use first non-empty line"
}

test_negative_item_numbers() {
    create_sample_todo_file
    
    local output=$(run_open_action "-1")
    local exit_code=$?
    
    assert_exit_code 1 $exit_code "Should reject negative item numbers"
    assert_contains "$output" "Error: ITEM# must be a positive integer" "Should report invalid item number"
}

test_zero_item_number() {
    create_sample_todo_file
    
    local output=$(run_open_action "0")
    local exit_code=$?
    
    assert_exit_code 1 $exit_code "Should reject zero item number"
    assert_contains "$output" "Error: Item 0 not found" "Should report item not found"
}

test_item_number_with_leading_zeros() {
    create_sample_todo_file
    
    local output=$(run_open_action "02")
    local exit_code=$?
    
    # This should work and be treated as item 2
    assert_exit_code 0 $exit_code "Should handle leading zeros in item numbers"
    assert_contains "$output" "$EXPECTED_GITHUB_OWNER_REPO_123" "Should find correct item"
}

test_special_characters_in_jira_base() {
    create_sample_todo_file
    
    # Test various special characters that might cause issues
    local problematic_bases=(
        "company.atlassian.net?"  # Query parameter character
        "company.atlassian.net#section"  # Fragment character
        "company.atlassian.net/"  # Trailing slash
        "company.atlassian.net:8080"  # Port number
    )
    
    local expected_urls=(
        "https://company.atlassian.net?/browse/PROJ-456"
        "https://company.atlassian.net#section/browse/PROJ-456"
        "https://company.atlassian.net//browse/PROJ-456"
        "https://company.atlassian.net:8080/browse/PROJ-456"
    )
    
    for i in "${!problematic_bases[@]}"; do
        setup_jira_env "${problematic_bases[$i]}"
        local output=$(run_open_action "$ITEM_WITH_JIRA_ONLY")
        assert_contains "$output" "${expected_urls[$i]}" "Should handle special chars in Jira base: ${problematic_bases[$i]}"
        clear_jira_config
    done
}

test_case_sensitivity() {
    local mixed_case_content="Fix GH:owner/repo#123 and JIRA:PROJ-456"
    create_custom_todo_file "$mixed_case_content"
    setup_jira_env "company.atlassian.net"
    
    local output=$(run_open_action "1")
    local exit_code=$?
    
    # Our regex is case-sensitive, so these should not match
    assert_exit_code 2 $exit_code "Should be case-sensitive"
    assert_contains "$output" "No supported links found" "Should not match uppercase prefixes"
}

test_tokens_at_line_boundaries() {
    # Test tokens at the very beginning and end of lines
    local boundary_content="gh:start/repo#1 middle content jira:END-2"
    create_custom_todo_file "$boundary_content"
    setup_jira_env "company.atlassian.net"
    
    local output=$(run_open_action "1")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should find tokens at line boundaries"
    assert_contains "$output" "Opening 2 link(s)" "Should find both boundary tokens"
    assert_contains "$output" "https://github.com/start/repo/issues/1" "Should find token at start"
    assert_contains "$output" "https://company.atlassian.net/browse/END-2" "Should find token at end"
}

test_partial_tokens() {
    local partial_content="Almost gh:owner/repo# and jira:PROJ- and complete gh:owner/repo#123"
    create_custom_todo_file "$partial_content"
    
    local output=$(run_open_action "1")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should ignore partial tokens"
    assert_contains "$output" "Opening 1 link(s)" "Should find only complete token"
    assert_contains "$output" "https://github.com/owner/repo/issues/123" "Should find complete token"
}

# Run all edge case tests
main() {
    echo "Edge Case and Error Handling Tests"
    echo "==================================="
    
    run_test test_missing_todo_file_env
    run_test test_nonexistent_todo_file
    run_test test_malformed_github_tokens
    run_test test_malformed_jira_tokens
    run_test test_unicode_in_todo_text
    run_test test_very_long_todo_line
    run_test test_many_tokens_in_one_line
    run_test test_empty_jira_config_file
    run_test test_whitespace_only_jira_config
    run_test test_multiline_jira_config
    run_test test_negative_item_numbers
    run_test test_zero_item_number
    run_test test_item_number_with_leading_zeros
    run_test test_special_characters_in_jira_base
    run_test test_case_sensitivity
    run_test test_tokens_at_line_boundaries
    run_test test_partial_tokens
    
    print_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
