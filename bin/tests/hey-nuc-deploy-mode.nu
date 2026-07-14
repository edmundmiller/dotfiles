#!/usr/bin/env nu

use std/assert
source ../hey.d/common.nu
source ../hey.d/remote.nu

assert equal (nuc-deploy-mode "nuc") "local"
assert equal (nuc-deploy-mode "mactraitorpro") "worktree-remote"
assert equal (nuc-deploy-mode "seqeratop") "worktree-remote"

let temp_dir = (^mktemp -d | str trim)
let source_dir = ($temp_dir | path join "linked-worktree")
let destination_dir = ($temp_dir | path join "synced")
mkdir $source_dir
"gitdir: /local-only/.git/worktrees/linked-worktree" | save ($source_dir | path join ".git")
"test" | save ($source_dir | path join "flake.nix")

nuc-worktree-rsync $"($source_dir)/" $"($destination_dir)/"

assert not (($destination_dir | path join ".git") | path exists) "linked-worktree .git pointer must not be synced"
assert (($destination_dir | path join "flake.nix") | path exists) "worktree contents must still be synced"
rm -rf $temp_dir

print "hey nuc deploy mode tests passed"
