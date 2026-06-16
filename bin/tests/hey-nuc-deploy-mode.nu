#!/usr/bin/env nu

use std/assert
source ../hey.d/common.nu
source ../hey.d/remote.nu

assert equal (nuc-deploy-mode "nuc") "local"
assert equal (nuc-deploy-mode "mactraitorpro") "worktree-remote"
assert equal (nuc-deploy-mode "seqeratop") "worktree-remote"

print "hey nuc deploy mode tests passed"
