#!/usr/bin/env nu

use std/assert
source ../hey.d/common.nu

# This test lives in bin/tests/, so repo root is two levels up.
let expected_repo_root = ($env.FILE_PWD | path join ".." ".." | path expand)
let ctx = (context)

assert equal $ctx.flake_dir $expected_repo_root

# `hey re` must work from anywhere after `hey` is installed into the Nix
# profile/store. Reproduce that shape with a temporary copy outside the repo:
# runner.nu sources ./hey.d/common.nu, while the shell's cwd is $HOME.
let tmp_root = (($env.TMPDIR? | default "/tmp") | path join "hey-context-installed")
rm -rf $tmp_root
mkdir ($tmp_root | path join "hey.d")
cp ($expected_repo_root | path join "bin" "hey.d" "common.nu") ($tmp_root | path join "hey.d" "common.nu")
'#!/usr/bin/env nu
source ./hey.d/common.nu
(context).flake_dir | print
' | save -f ($tmp_root | path join "runner.nu")

cd $env.HOME
let installed_ctx = (^nu ($tmp_root | path join "runner.nu") | str trim)
assert equal $installed_ctx $expected_repo_root

print "hey context tests passed"
