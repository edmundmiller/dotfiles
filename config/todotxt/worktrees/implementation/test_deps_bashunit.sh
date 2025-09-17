#!/usr/bin/env bash

# BashUnit test suite for deps action

# Test setup - create temp todo file for testing
function set_up() {
    TEST_TODO_FILE=$(temp_file "todo")
    export TODO_FILE="$TEST_TODO_FILE"
}

# Cleanup after each test
function tear_down() {
    [[ -f "$TEST_TODO_FILE" ]] && rm -f "$TEST_TODO_FILE"
}

function test_deps_ready_shows_tasks_with_no_dependencies() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task A with no dependencies id:a
Task B depends on A dep:a id:b
Task C depends on B depends:b id:c
EOF

    local output
    output=$(./deps ready)
    
    assert_contains "Task A with no dependencies" "$output"
    assert_not_contains "Task B depends on A" "$output"
    assert_not_contains "Task C depends on B" "$output"
}

function test_deps_blocked_identifies_dependent_tasks() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task A with no dependencies id:a
Task B depends on A dep:a id:b
Task C depends on B depends:b id:c
EOF

    local output
    output=$(./deps blocked)
    
    assert_contains "Task B" "$output"
    assert_contains "Task C" "$output"
    assert_contains "Blocked by:" "$output"
}

function test_deps_blocking_identifies_tasks_that_block_others() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task A with no dependencies id:a
Task B depends on A dep:a id:b
Task C depends on B depends:b id:c
EOF

    local output
    output=$(./deps blocking)
    
    assert_contains "Task A" "$output"
    assert_contains "Task B" "$output"
    assert_contains "Blocks:" "$output"
}

function test_deps_chain_traces_dependency_path() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task A with no dependencies id:a
Task B depends on A dep:a id:b
Task C depends on B depends:b id:c
EOF

    local output
    output=$(./deps chain c)
    
    assert_contains "Task C" "$output"
    assert_contains "Task B" "$output"
    assert_contains "Task A" "$output"
    assert_contains "Dependency chain for 'c'" "$output"
}

function test_deps_chain_shows_no_dependencies_message() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task A with no dependencies id:a
EOF

    local output
    output=$(./deps chain a)
    
    assert_contains "No dependencies (ready to start)" "$output"
}

function test_deps_validate_detects_circular_dependencies() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task X depends on Y dep:y id:x
Task Y depends on X dep:x id:y
EOF

    local output
    output=$(./deps validate)
    
    assert_contains "Circular dependency" "$output"
    assert_contains "x → y → x" "$output"
}

function test_deps_validate_detects_orphaned_references() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task depends on missing task dep:missing id:task1
EOF

    local output
    output=$(./deps validate)
    
    assert_contains "depends on missing task 'missing'" "$output"
}

function test_deps_validate_shows_no_issues_for_valid_dependencies() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task A id:a
Task B dep:a id:b
EOF

    local output
    output=$(./deps validate)
    
    assert_same "No dependency issues found" "$output"
}

function test_deps_addids_generates_uuids_for_tasks_without_ids() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task without ID
Task with ID id:has-id
Another without ID
EOF

    local output
    output=$(./deps addids)
    
    assert_contains "Added id:" "$output"
    assert_file_contains "$TEST_TODO_FILE" "id:"
    
    # Check that all tasks now have IDs
    local id_count
    id_count=$(grep -c "id:" "$TEST_TODO_FILE" || true)
    assert_equals 3 "$id_count"
}

function test_deps_addids_preserves_existing_ids() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task with existing ID id:existing
EOF

    ./deps addids > /dev/null
    
    # Should still have exactly one ID and it should be the original
    assert_file_contains "$TEST_TODO_FILE" "id:existing"
    local id_count
    id_count=$(grep -c "id:" "$TEST_TODO_FILE")
    assert_equals 1 "$id_count"
}

function test_deps_supports_mixed_dep_and_depends_syntax() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task A id:a
Task B dep:a id:b
Task C depends:b id:c
Task D dep:a,c id:d
EOF

    local output
    output=$(./deps blocked)
    
    assert_contains "Task B" "$output"
    assert_contains "Task C" "$output"
    assert_contains "Task D" "$output"
}

function test_deps_tree_shows_hierarchical_view() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task A id:a
Task B dep:a id:b
Task C dep:b id:c
EOF

    local output
    output=$(./deps tree)
    
    assert_contains "📋" "$output"  # Root task symbol
    assert_contains "└─" "$output"  # Tree structure
    assert_contains "⏳" "$output"  # Blocked task symbol
    assert_contains "Task A" "$output"
    assert_contains "Task B" "$output"
    assert_contains "Task C" "$output"
}

function test_deps_tree_handles_circular_dependencies_gracefully() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task X dep:y id:x
Task Y dep:x id:y
EOF

    local output
    output=$(./deps tree)
    
    # Should either show circular or detect that all have dependencies
    local exit_code
    ./deps tree > /dev/null
    exit_code=$?
    assert_equals 0 "$exit_code"  # Should not crash
    
    # Check that it handles the circular case gracefully  
    if [[ "$output" == *"CIRCULAR"* || "$output" == *"No root tasks"* ]]; then
        assert_true true
    else
        assert_true false
    fi
}

function test_deps_handles_nonexistent_task_id_in_chain() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task A id:a
EOF

    local output
    output=$(./deps chain nonexistent)
    
    assert_contains "Task ID 'nonexistent' not found" "$output"
}

function test_deps_usage_shows_help_information() {
    local output
    output=$(./deps usage)
    
    assert_contains "deps - Task dependency management" "$output"
    assert_contains "deps blocked" "$output"
    assert_contains "deps blocking" "$output"
    assert_contains "deps ready" "$output"
    assert_contains "deps chain" "$output"
    assert_contains "deps tree" "$output"
    assert_contains "deps validate" "$output"
    assert_contains "deps addids" "$output"
}

function test_deps_skips_completed_tasks() {
    cat > "$TEST_TODO_FILE" << 'EOF'
x 2024-01-01 Completed task id:done
Task A id:a
Task B dep:a id:b
EOF

    local output
    output=$(./deps ready)
    
    assert_not_contains "Completed task" "$output"
    assert_contains "Task A" "$output"
}

function test_deps_handles_comma_separated_dependencies() {
    cat > "$TEST_TODO_FILE" << 'EOF'
Task A id:a
Task B id:b
Task C dep:a,b id:c
EOF

    local output
    output=$(./deps blocked)
    
    assert_contains "Task C" "$output"
    assert_contains "Blocked by: a, b" "$output"
}

# Custom assertion for checking that deps action exists and is executable
function test_deps_action_is_executable() {
    assert_file_exists "./deps"
    if [[ -x "./deps" ]]; then
        assert_true true
    else
        assert_true false
    fi
}

# Integration test: full workflow
function test_deps_full_workflow_integration() {
    # Note: set_test_title might not be available in this version
    
    # Create a realistic task hierarchy
    cat > "$TEST_TODO_FILE" << 'EOF'
Plan project id:plan +work
Research requirements dep:plan id:research +work
Design architecture dep:research id:design +work
Implement core dep:design id:core +work
Write tests dep:core id:tests +work
Deploy application dep:tests id:deploy +work
EOF

    # Test that blocking relationships work correctly
    local blocking_output
    blocking_output=$(./deps blocking)
    assert_contains "plan" "$blocking_output"
    assert_contains "research" "$blocking_output"
    
    # Test that ready tasks are identified
    local ready_output  
    ready_output=$(./deps ready)
    assert_contains "Plan project" "$ready_output"
    assert_not_contains "Deploy application" "$ready_output"
    
    # Test chain tracing works end-to-end
    local chain_output
    chain_output=$(./deps chain deploy)
    assert_contains "Plan project" "$chain_output"
    assert_contains "Deploy application" "$chain_output"
    
    # Test tree view shows the hierarchy
    local tree_output
    tree_output=$(./deps tree)
    assert_contains "📋" "$tree_output"
    assert_contains "Plan project" "$tree_output"
    
    # Validation should pass
    local validation_output
    validation_output=$(./deps validate)
    assert_same "No dependency issues found" "$validation_output"
}
