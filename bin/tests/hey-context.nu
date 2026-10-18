#!/usr/bin/env nu

use std/assert
use ../../scripts/nu/common.nu *

# This test lives in bin/tests/, so repo root is two levels up.
let expected_repo_root = ($env.FILE_PWD | path join ".." ".." | path expand)
let ctx = (context)

assert equal $ctx.flake_dir $expected_repo_root

# Mise chooses the checkout even when the caller inherited global dotfiles vars.
with-env { MISE_PROJECT_ROOT: $expected_repo_root, FLAKE_DIR: "/wrong-checkout", DOTFILES: "/also-wrong" } {
  cd $env.HOME
  assert equal (context).flake_dir $expected_repo_root
}

print "hey context tests passed"
