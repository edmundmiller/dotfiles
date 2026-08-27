#!/usr/bin/env nu

use std/assert
source ../hey.d/common.nu
source ../hey.d/remote.nu

assert equal (nuc-deploy-mode "nuc") "local"
assert equal (nuc-deploy-mode "mactraitorpro") "worktree-remote"
assert equal (nuc-deploy-mode "seqeratop") "worktree-remote"
assert equal (nuc-worktree-configuration "nuc") "nuc"
assert equal (nuc-worktree-configuration "nuc-buzz-scintillate") "nuc-buzz-scintillate"
assert equal (nuc-worktree-configuration "nuc-buzz-scintillate-finn") "nuc-buzz-scintillate-finn"
assert equal (nuc-worktree-configuration "nuc-buzz-scintillate-finn-amosburton") "nuc-buzz-scintillate-finn-amosburton"
assert equal (nuc-worktree-configuration "nuc-buzz-scintillate-finn-amosburton-anne") "nuc-buzz-scintillate-finn-amosburton-anne"

let source_revision = "1111111111111111111111111111111111111111"
let revision_command = (nuc-worktree-revision-command "/tmp/dotfiles-worktree-test" $source_revision)
assert equal $revision_command "bash '/tmp/dotfiles-worktree-test/bin/write-nuc-deploy-revision' '/tmp/dotfiles-worktree-test' '1111111111111111111111111111111111111111'"

let clean_source = {head: $source_revision, base: $source_revision, owner: "test", dirty: false}
let dirty_source = {head: $source_revision, base: $source_revision, owner: "test", dirty: true}
let clean_remote_dir_one = (nuc-worktree-remote-dir "tester" $clean_source)
let clean_remote_dir_two = (nuc-worktree-remote-dir "tester" $clean_source)
let dirty_remote_dir = (nuc-worktree-remote-dir "tester" $dirty_source)
assert ($clean_remote_dir_one | str starts-with $"/tmp/dotfiles-worktree-tester-($source_revision)-clean-")
assert not ($clean_remote_dir_one == $clean_remote_dir_two) "concurrent clean deploys must use isolated remote directories"
assert ($dirty_remote_dir | str starts-with $"/tmp/dotfiles-worktree-tester-($source_revision)-dirty-")
for mode in ["dry-activate" "test" "switch"] {
  let dirty_activation_blocked = (try {
    require-clean-nuc-activation $dirty_source $mode
    false
  } catch {|err|
    $err.msg | str contains "dirty worktree"
  })
  assert $dirty_activation_blocked
}
require-clean-nuc-activation $dirty_source "build"
require-clean-nuc-activation $dirty_source "vm"
let lifecycle_script = (nuc-worktree-lifecycle-script "/tmp/dotfiles-worktree-test" "tester" "true")
assert ($lifecycle_script | str contains "trap cleanup EXIT")
assert ($lifecycle_script | str contains "/tmp/dotfiles-worktree-test/.nuc-deploy-active")
assert ($lifecycle_script | str contains "prune-nuc-deploy-snapshots' '/tmp' 'tester' 5")

let temp_dir = (^mktemp -d | str trim)
let source_dir = ($temp_dir | path join "source")
let clean_destination_dir = ($temp_dir | path join "clean-synced")
let dirty_destination_dir = ($temp_dir | path join "dirty-synced")
let failed_prepare_source = ($temp_dir | path join "failed-prepare-source")
let failed_prepare_destination = ($temp_dir | path join $"dotfiles-worktree-tester-($source_revision)-dirty-20000000-0000-0000-0000-000000000000")
let prune_root = ($temp_dir | path join "prune-root")
let lifecycle_destination = ($temp_dir | path join "lifecycle")
let repo_root = ($env.DOTFILES_TEST_ROOT? | default (pwd))
let revision_writer = ($repo_root | path join "bin" "write-nuc-deploy-revision")
let snapshot_pruner = ($repo_root | path join "bin" "prune-nuc-deploy-snapshots")
mkdir ($source_dir | path join "bin")
mkdir ($lifecycle_destination | path join "bin")
^cp $snapshot_pruner ($lifecycle_destination | path join "bin" "prune-nuc-deploy-snapshots")
"active" | save ($lifecycle_destination | path join ".nuc-deploy-active")
let lifecycle_failure = (nuc-worktree-lifecycle-command $lifecycle_destination "tester" "exit 7")
let lifecycle_result = (^bash -c $lifecycle_failure | complete)
assert equal $lifecycle_result.exit_code 7
assert not (($lifecycle_destination | path join ".nuc-deploy-active") | path exists) "remote lifecycle cleanup must release its active lease while preserving command status"
"test" | save ($source_dir | path join "flake.nix")
"ignored.txt" | save ($source_dir | path join ".gitignore")
"ignored" | save ($source_dir | path join "ignored.txt")
^cp $revision_writer ($source_dir | path join "bin" "write-nuc-deploy-revision")
^git -C $source_dir init --quiet --initial-branch main
^git -C $source_dir add flake.nix .gitignore bin/write-nuc-deploy-revision
^git -C $source_dir -c user.name=Test -c user.email=test@example.invalid commit --quiet -m fixture
let fixture_revision = (^git -C $source_dir rev-parse HEAD | str trim)
^git -C $source_dir update-ref refs/remotes/origin/main $fixture_revision
"mutated after status could have been checked" | save --force ($source_dir | path join "flake.nix")
^git -C $source_dir update-index --assume-unchanged flake.nix

let detected_clean_source = (nuc-deploy-source $source_dir)
assert equal $detected_clean_source.head $fixture_revision
assert equal $detected_clean_source.base $fixture_revision
assert not $detected_clean_source.dirty
nuc-worktree-sync $source_dir $clean_destination_dir $fixture_revision $detected_clean_source.dirty

assert (($clean_destination_dir | path join "bin" "write-nuc-deploy-revision") | path exists) "clean snapshots must include the tracked revision writer"
let marker_command = (nuc-worktree-revision-command $clean_destination_dir $fixture_revision)
let marker_result = (^bash -c $marker_command | complete)
assert equal $marker_result.exit_code 0

assert not (($clean_destination_dir | path join ".git") | path exists) "worktree Git metadata must not be synced"
assert (($clean_destination_dir | path join "flake.nix") | path exists) "tracked worktree contents must still be synced"
assert not (($clean_destination_dir | path join "ignored.txt") | path exists) "clean snapshots must exclude ignored content"
assert equal (open --raw ($clean_destination_dir | path join "flake.nix")) (^git -C $source_dir show HEAD:flake.nix) "clean snapshots must materialize committed blobs, not assume-unchanged worktree content"
assert equal (open --raw ($clean_destination_dir | path join ".nuc-deploy-source-revision")) $fixture_revision
let invalid_marker_result = (^bash $revision_writer $clean_destination_dir invalid | complete)
assert equal $invalid_marker_result.exit_code 2
assert equal (open --raw ($clean_destination_dir | path join ".nuc-deploy-source-revision")) $fixture_revision

"uncommitted" | save ($source_dir | path join "untracked.txt")
let detected_dirty_source = (nuc-deploy-source $source_dir)
assert $detected_dirty_source.dirty
require-clean-nuc-activation $detected_dirty_source "build"
mkdir $dirty_destination_dir
"active" | save ($dirty_destination_dir | path join ".nuc-deploy-active")
nuc-worktree-sync $source_dir $dirty_destination_dir $fixture_revision $detected_dirty_source.dirty
assert (($dirty_destination_dir | path join "untracked.txt") | path exists) "dirty build snapshots must include the tested worktree content"
assert not (($dirty_destination_dir | path join ".git") | path exists) "dirty snapshots must still exclude Git metadata"
assert (($dirty_destination_dir | path join ".nuc-deploy-active") | path exists) "dirty rsync must preserve the destination-only active lease"

mkdir ($failed_prepare_source | path join "bin")
mkdir $failed_prepare_destination
^cp $snapshot_pruner ($failed_prepare_source | path join "bin" "prune-nuc-deploy-snapshots")
"active" | save ($failed_prepare_destination | path join ".nuc-deploy-active")
let prepare_failed = (try {
  nuc-worktree-prepare $failed_prepare_source $failed_prepare_destination $fixture_revision true tester "" $temp_dir
  false
} catch {
  true
})
assert $prepare_failed "missing revision writer must fail snapshot preparation"
assert not (($failed_prepare_destination | path join ".nuc-deploy-active") | path exists) "failed snapshot preparation must release its active lease"

mkdir $prune_root
let snapshot_uuids = [
  "00000000-0000-0000-0000-000000000001"
  "00000000-0000-0000-0000-000000000002"
  "00000000-0000-0000-0000-000000000003"
  "00000000-0000-0000-0000-000000000004"
  "00000000-0000-0000-0000-000000000005"
  "00000000-0000-0000-0000-000000000006"
]
for item in ($snapshot_uuids | enumerate) {
  let snapshot = ($prune_root | path join $"dotfiles-worktree-tester-($source_revision)-clean-($item.item)")
  mkdir $snapshot
  ^touch -d $"2020-01-01 00:00:0($item.index + 1) UTC" $snapshot
}
let legacy_snapshot = ($prune_root | path join "dotfiles-worktree-tester-trmnl-enrollment")
mkdir $legacy_snapshot
let active_snapshot = ($prune_root | path join $"dotfiles-worktree-tester-($source_revision)-clean-10000000-0000-0000-0000-000000000000")
mkdir $active_snapshot
"active" | save ($active_snapshot | path join ".nuc-deploy-active")
let prune_result = (^bash $snapshot_pruner $prune_root tester 2 | complete)
assert equal $prune_result.exit_code 0
assert equal ((glob ($prune_root | path join $"dotfiles-worktree-tester-($source_revision)-*") | length)) 3
assert (($prune_root | path join $"dotfiles-worktree-tester-($source_revision)-clean-00000000-0000-0000-0000-000000000006") | path exists) "snapshot pruning must retain the newest directory"
assert (($prune_root | path join $"dotfiles-worktree-tester-($source_revision)-clean-00000000-0000-0000-0000-000000000005") | path exists) "snapshot pruning must retain the configured count"
assert ($legacy_snapshot | path exists) "snapshot pruning must not remove legacy or unrelated task directories"
assert ($active_snapshot | path exists) "snapshot pruning must not remove an active deployment"
rm ($active_snapshot | path join ".nuc-deploy-active")
let post_run_prune_result = (^bash $snapshot_pruner $prune_root tester 2 | complete)
assert equal $post_run_prune_result.exit_code 0
assert equal ((glob ($prune_root | path join $"dotfiles-worktree-tester-($source_revision)-*") | length)) 2
assert not (($active_snapshot | path join ".nuc-deploy-active") | path exists) "completed deployments must release their active lease"
rm -rf $temp_dir

print "hey nuc deploy mode tests passed"
