#!/usr/bin/env nu

use std/assert
source ../hey.d/common.nu
source ../hey.d/remote.nu

assert equal (nuc-deploy-mode "nuc") "deploy-rs-local"
assert equal (nuc-deploy-mode "mactraitorpro") "deploy-rs-remote"
assert equal (nuc-deploy-mode "seqeratop") "deploy-rs-remote"

print "hey nuc deploy mode tests passed"
