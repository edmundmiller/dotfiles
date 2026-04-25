#!/usr/bin/env nu

use std/assert
source ../hey.d/common.nu

# This test lives in bin/tests/, so repo root is two levels up.
let expected_repo_root = ($env.FILE_PWD | path join ".." ".." | path expand)
let ctx = (context)

assert equal $ctx.flake_dir $expected_repo_root
print "hey context tests passed"
