#!/bin/bash
# Integration tests for the open action

# Source the test framework and fixtures
source "$(dirname "$0")/test_framework.sh"
source "$(dirname "$0")/test_fixtures.sh"

test_usage_help() {
    local output=$(run_open_action "usage")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Usage help should exit with code 0"
    assert_contains "$output" "Usage: todo.sh open ITEM#" "Usage should show correct usage"
    assert_contains "$output" "gh:owner/repo#123" "Usage should show GitHub example"
    assert_contains "$output" "jira:TICKET-123" "Usage should show Jira example"
    assert_contains "$output" "JIRA_BASE_URL" "Usage should mention Jira config"
}

test_github_only_with_jira_config() {
    create_sample_todo_file
    setup_jira_env "company.atlassian.net"
    
    local output=$(run_open_action "$ITEM_WITH_GITHUB_ONLY")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should succeed with GitHub-only item"
    assert_contains "$output" "Opening 1 link(s)" "Should report opening 1 link"
    assert_contains "$output" "$EXPECTED_GITHUB_OWNER_REPO_123" "Should show GitHub URL"
    
    # Check that URL was actually "opened"
    local url_count=$(count_opened_urls)
    assert_equals "1" "$url_count" "Should open exactly 1 URL"
    
    if url_was_opened "$EXPECTED_GITHUB_OWNER_REPO_123"; then
        assert_equals "true" "true" "GitHub URL was opened"
    else
        assert_equals "opened" "not-opened" "GitHub URL should have been opened"
    fi
}

test_jira_only_with_config() {
    create_sample_todo_file
    setup_jira_env "company.atlassian.net"
    
    local output=$(run_open_action "$ITEM_WITH_JIRA_ONLY")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should succeed with Jira-only item"
    assert_contains "$output" "Opening 1 link(s)" "Should report opening 1 link"
    assert_contains "$output" "$EXPECTED_JIRA_PROJ_456_ATLASSIAN" "Should show Jira URL"
    
    local url_count=$(count_opened_urls)
    assert_equals "1" "$url_count" "Should open exactly 1 URL"
    
    if url_was_opened "$EXPECTED_JIRA_PROJ_456_ATLASSIAN"; then
        assert_equals "true" "true" "Jira URL was opened"
    else
        assert_equals "opened" "not-opened" "Jira URL should have been opened"
    fi
}

test_multiple_links() {
    create_sample_todo_file
    setup_jira_env "company.atlassian.net"
    
    local output=$(run_open_action "$ITEM_WITH_BOTH")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should succeed with multiple links"
    assert_contains "$output" "Opening 2 link(s)" "Should report opening 2 links"
    assert_contains "$output" "$EXPECTED_GITHUB_NFCORE_MODULES_2230" "Should show GitHub URL"
    assert_contains "$output" "$EXPECTED_JIRA_SD_789_ATLASSIAN" "Should show Jira URL"
    
    local url_count=$(count_opened_urls)
    assert_equals "2" "$url_count" "Should open exactly 2 URLs"
}

test_no_links_found() {
    create_sample_todo_file
    setup_jira_env "company.atlassian.net"
    
    local output=$(run_open_action "$ITEM_WITHOUT_LINKS")
    local exit_code=$?
    
    assert_exit_code 2 $exit_code "Should exit with code 2 when no links found"
    assert_contains "$output" "No supported links found" "Should report no links found"
    assert_contains "$output" "Regular task without links" "Should show the todo text"
    
    local url_count=$(count_opened_urls)
    assert_equals "0" "$url_count" "Should not open any URLs"
}

test_jira_config_via_file() {
    create_sample_todo_file
    setup_jira_file "jira.mycompany.com"
    
    local output=$(run_open_action "$ITEM_WITH_JIRA_ONLY")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should succeed with file-based Jira config"
    assert_contains "$output" "https://jira.mycompany.com/browse/PROJ-456" "Should use file-based URL"
}

test_jira_without_config() {
    create_sample_todo_file
    clear_jira_config
    
    local output=$(run_open_action "$ITEM_WITH_JIRA_ONLY")
    local exit_code=$?
    
    assert_exit_code 2 $exit_code "Should exit with code 2 when Jira config missing"
    assert_contains "$output" "Warning: Found Jira tokens but JIRA_BASE_URL is not configured" "Should warn about missing config"
    assert_contains "$output" "No supported links found" "Should report no links since Jira config missing"
}

test_mixed_links_missing_jira_config() {
    create_sample_todo_file
    clear_jira_config
    
    local output=$(run_open_action "$ITEM_WITH_BOTH")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should succeed and open GitHub link even without Jira config"
    assert_contains "$output" "Warning: Found Jira tokens but JIRA_BASE_URL is not configured" "Should warn about missing Jira config"
    assert_contains "$output" "Opening 1 link(s)" "Should open just the GitHub link"
    assert_contains "$output" "$EXPECTED_GITHUB_NFCORE_MODULES_2230" "Should show GitHub URL"
    
    local url_count=$(count_opened_urls)
    assert_equals "1" "$url_count" "Should open exactly 1 URL (GitHub only)"
}

test_item_not_found() {
    create_sample_todo_file
    
    local output=$(run_open_action "$ITEM_NONEXISTENT")
    local exit_code=$?
    
    assert_exit_code 1 $exit_code "Should exit with code 1 when item not found"
    assert_contains "$output" "Error: Item $ITEM_NONEXISTENT not found" "Should report item not found"
}

test_missing_item_argument() {
    create_sample_todo_file
    
    local output=$(run_open_action "")
    local exit_code=$?
    
    assert_exit_code 1 $exit_code "Should exit with code 1 when item number missing"
    assert_contains "$output" "Error: Missing ITEM#" "Should report missing item number"
    assert_contains "$output" "Usage: todo.sh open ITEM#" "Should show usage"
}

test_invalid_item_argument() {
    create_sample_todo_file
    
    local output=$(run_open_action "abc")
    local exit_code=$?
    
    assert_exit_code 1 $exit_code "Should exit with code 1 when item number invalid"
    assert_contains "$output" "Error: ITEM# must be a positive integer" "Should report invalid item number"
}

test_empty_todo_file() {
    create_custom_todo_file ""
    
    local output=$(run_open_action "1")
    local exit_code=$?
    
    assert_exit_code 1 $exit_code "Should exit with code 1 when todo file empty"
    assert_contains "$output" "Error: Item 1 not found" "Should report item not found in empty file"
}

test_jira_url_normalization() {
    create_sample_todo_file
    
    # Test different Jira URL formats
    local test_cases=(
        "company.atlassian.net"
        "https://company.atlassian.net"
        "http://company.atlassian.net"
        "jira.company.com"
    )
    
    local expected_urls=(
        "https://company.atlassian.net/browse/PROJ-456"
        "https://company.atlassian.net/browse/PROJ-456"
        "http://company.atlassian.net/browse/PROJ-456"
        "https://jira.company.com/browse/PROJ-456"
    )
    
    for i in "${!test_cases[@]}"; do
        setup_jira_env "${test_cases[$i]}"
        local output=$(run_open_action "$ITEM_WITH_JIRA_ONLY")
        assert_contains "$output" "${expected_urls[$i]}" "URL normalization should work for: ${test_cases[$i]}"
        clear_jira_config
    done
}

test_complex_github_names() {
    local todo_content="Test gh:complex.name/repo_name#12345 and gh:user-name/project.name#999"
    create_custom_todo_file "$todo_content"
    
    local output=$(run_open_action "1")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should handle complex GitHub names"
    assert_contains "$output" "Opening 2 link(s)" "Should find both GitHub links"
    assert_contains "$output" "https://github.com/complex.name/repo_name/issues/12345" "Should handle complex owner/repo names"
    assert_contains "$output" "https://github.com/user-name/project.name/issues/999" "Should handle dashes and dots"
}

test_complex_jira_names() {
    local todo_content="Track jira:PROJECT_NAME-123 and jira:TEAM.SUB-456"
    create_custom_todo_file "$todo_content"
    setup_jira_env "company.atlassian.net"
    
    local output=$(run_open_action "1")
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "Should handle complex Jira names"
    assert_contains "$output" "Opening 2 link(s)" "Should find both Jira links"
    assert_contains "$output" "https://company.atlassian.net/browse/PROJECT_NAME-123" "Should handle underscore in project name"
    assert_contains "$output" "https://company.atlassian.net/browse/TEAM.SUB-456" "Should handle dots in project name"
}

# Run all integration tests
main() {
    echo "Integration Tests"
    echo "=================="
    
    run_test test_usage_help
    run_test test_github_only_with_jira_config
    run_test test_jira_only_with_config
    run_test test_multiple_links
    run_test test_no_links_found
    run_test test_jira_config_via_file
    run_test test_jira_without_config
    run_test test_mixed_links_missing_jira_config
    run_test test_item_not_found
    run_test test_missing_item_argument
    run_test test_invalid_item_argument
    run_test test_empty_todo_file
    run_test test_jira_url_normalization
    run_test test_complex_github_names
    run_test test_complex_jira_names
    
    print_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
