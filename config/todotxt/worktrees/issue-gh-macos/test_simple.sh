#!/bin/bash

function test_simple() {
  assert_equals "hello" "hello"
  assert_contains "hello world" "world"  
  assert_not_equals "foo" "bar"
}
