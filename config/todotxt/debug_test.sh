#!/usr/bin/env bash

function test_simple_contains() {
    local full_text="hello world this is a test"
    assert_contains "$full_text" "hello"
    assert_contains "$full_text" "world"  
    assert_contains "$full_text" "test"
}

function test_tracktime_help() {
    local output=$(./tracktime help 2>&1)
    echo "=== OUTPUT START ==="
    echo "$output"
    echo "=== OUTPUT END ==="
    
    assert_contains "$output" "tracktime"
}
