#!/bin/bash

function test_simple_pass() {
  assert_equals "hello" "hello"
}

function test_contains_check() {
  local text="hello world"
  assert_contains "world" "$text"
}
