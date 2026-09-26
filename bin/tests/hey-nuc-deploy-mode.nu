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
for mode in ["dry-activate" "test" "switch" "build" "vm" "validate"] {
  validate-nuc-worktree-mode $mode
}
for mode in ["none" "build" "dry-activate" "test" "switch"] {
  assert equal (agents-rollout-deploy-mode $mode) $mode
}
let invalid_agents_rollout_mode_blocked = (try {
  agents-rollout-deploy-mode "vm"
  false
} catch {|err|
  $err.msg | str contains "invalid agents rollout deploy mode"
})
assert $invalid_agents_rollout_mode_blocked

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
let pin_fixture = ($temp_dir | path join "flake-pin.nix")
let old_agents_revision = "2222222222222222222222222222222222222222"
let new_agents_revision = "3333333333333333333333333333333333333333"
$"url = \"github:edmundmiller/agents-workspace/($old_agents_revision)\";" | save $pin_fixture
pin-agents-workspace-input $pin_fixture $new_agents_revision
let pinned_fixture = (open --raw $pin_fixture)
assert ($pinned_fixture | str contains $"agents-workspace/($new_agents_revision)")
assert not ($pinned_fixture | str contains $old_agents_revision)
let invalid_agents_revision_blocked = (try {
  pin-agents-workspace-input $pin_fixture "not-a-revision"
  false
} catch {|err|
  $err.msg | str contains "exact 40-character lowercase Git revision"
})
assert $invalid_agents_revision_blocked

let source_dir = ($temp_dir | path join "source")
let clean_destination_dir = ($temp_dir | path join "clean-synced")
let dirty_destination_dir = ($temp_dir | path join "dirty-synced")
let failed_prepare_source = ($temp_dir | path join "failed-prepare-source")
let failed_prepare_destination = ($temp_dir | path join $"dotfiles-worktree-tester-($source_revision)-dirty-20000000-0000-0000-0000-000000000000")
let prune_root = ($temp_dir | path join "prune-root")
let lifecycle_destination = ($temp_dir | path join "lifecycle")
let release_failure_destination = ($temp_dir | path join "release-failure")
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
let claimed_lease_destination = ($temp_dir | path join $"dotfiles-worktree-tester-($source_revision)-clean-00000000-0000-0000-0000-000000000006")
let claimed_lease_unit = "nuc-validation-00000000-0000-0000-0000-000000000006.service"
mkdir $claimed_lease_destination
assert equal (nuc-worktree-validation-unit $claimed_lease_destination) $claimed_lease_unit
nuc-worktree-claim-validation-lease $claimed_lease_destination $claimed_lease_unit
assert equal (open --raw ($claimed_lease_destination | path join ".nuc-deploy-active")) $"systemd-user-unit=($claimed_lease_unit)\n"
mkdir ($release_failure_destination | path join "bin")
"exit 23" | save ($release_failure_destination | path join "bin" "prune-nuc-deploy-snapshots")
"active" | save ($release_failure_destination | path join ".nuc-deploy-active")
let release_failure = (try {
  nuc-worktree-release $release_failure_destination tester "" $temp_dir
  false
} catch {
  true
})
assert $release_failure "snapshot release must surface pruning failure"
assert not (($release_failure_destination | path join ".nuc-deploy-active") | path exists) "snapshot release must still remove the active lease when pruning fails"
"active" | save ($release_failure_destination | path join ".nuc-deploy-active")
let lifecycle_cleanup_failure = (^bash -c (nuc-worktree-lifecycle-command $release_failure_destination tester "true") | complete)
assert equal $lifecycle_cleanup_failure.exit_code 1 "successful deployment command must surface cleanup failure"
"active" | save ($release_failure_destination | path join ".nuc-deploy-active")
let lifecycle_command_failure = (^bash -c (nuc-worktree-lifecycle-command $release_failure_destination tester "exit 7") | complete)
assert equal $lifecycle_command_failure.exit_code 7 "failed deployment command must preserve its original status when cleanup also fails"
let validation_service_command = (nuc-worktree-validation-service-command "exit 9" "exit 8" "nuc-validation-00000000-0000-0000-0000-000000000007.service")
assert ($validation_service_command | str contains "systemd-run --user --wait --collect")
assert ($validation_service_command | str contains "--unit='nuc-validation-00000000-0000-0000-0000-000000000007.service'")
assert ($validation_service_command | str contains "ExecStopPost=")
assert ($validation_service_command | str contains "--property=MemoryHigh=10G")
assert ($validation_service_command | str contains "--property=MemoryMax=12G")
assert ($validation_service_command | str contains "--property=OOMPolicy=continue")
let validation_source = ($temp_dir | path join "validation-source")
let validation_report_root = ($temp_dir | path join "validation-reports")
let validation_report = ($validation_report_root | path join "report")
let validation_bin = ($temp_dir | path join "validation-bin")
let validation_hooks = ($temp_dir | path join "validation-hooks")
let validation_flock_marker = ($temp_dir | path join "flock-called")
let validation_nix_config = ($temp_dir | path join "nix-config")
let validation_gate_invocations = ($temp_dir | path join "gate-invocations")
let validation_meminfo = ($temp_dir | path join "meminfo")
mkdir ($validation_source | path join "bin")
mkdir ($validation_source | path join "scripts")
mkdir $validation_report_root
mkdir $validation_bin
mkdir $validation_hooks
^cp $snapshot_pruner ($validation_source | path join "bin" "prune-nuc-deploy-snapshots")
"active" | save ($validation_source | path join ".nuc-deploy-active")
"" | save ($validation_source | path join "scripts" "validation.py")
"MemAvailable:   33554432 kB\n" | save $validation_meminfo
^git -C $validation_source init --quiet --initial-branch fixture
^git -C $validation_source add --force --all -- . ':(exclude).nuc-deploy-active'
let validation_content_digest = (^git -C $validation_source write-tree | str trim)
rm -rf ($validation_source | path join ".git")
let bash_path = (which bash | get 0.path)
let git_path = (which git | get 0.path)
let fake_python = r#'
#!__BASH__
printf 'python %s\n' "$*" >> "$NUC_TEST_GATE_INVOCATIONS"
if [[ "$*" == "scripts/validation.py --full" ]]; then
  exit 3
fi
exit 0
'#
let fake_nix = r#'
#!__BASH__
printf '%s' "$NIX_CONFIG" > "$NUC_TEST_NIX_CONFIG"
printf 'nix %s\n' "$*" >> "$NUC_TEST_GATE_INVOCATIONS"
exit 5
'#
let fake_flock = r#'
#!__BASH__
printf called > "$NUC_TEST_FLOCK_MARKER"
exit 0
'#
let fake_git = r#'
#!__BASH__
if [[ "${NUC_TEST_GIT_SETUP_FAILURE:-}" == 1 && "$*" == *" commit "* ]]; then
  exit 19
fi
exec __GIT__ "$@"
'#
$fake_python | str trim --left | str replace "__BASH__" $bash_path | save ($validation_bin | path join "python3")
$fake_nix | str trim --left | str replace "__BASH__" $bash_path | save ($validation_bin | path join "nix")
$fake_flock | str trim --left | str replace "__BASH__" $bash_path | save ($validation_bin | path join "flock")
$fake_git | str trim --left | str replace "__BASH__" $bash_path | str replace "__GIT__" $git_path | save ($validation_bin | path join "git")
"#!/usr/bin/env bash\nexit 97\n" | save ($validation_hooks | path join "pre-commit")
^chmod +x ($validation_bin | path join "python3") ($validation_bin | path join "nix") ($validation_bin | path join "flock") ($validation_bin | path join "git")
^chmod +x ($validation_hooks | path join "pre-commit")
"gate\tstatus\tlog_status\tlog\n" | save $"($validation_report).summary-template"
mkdir $validation_report
open --raw $"($validation_report).summary-template" | save ($validation_report | path join "summary.tsv")
"state\ttimestamp\tstatus\toutcome\tdetail\nqueued\tnow\t\t\t\n" | save ($validation_report | path join "state.tsv")
let validation_command = (nuc-worktree-validation-command $validation_source $validation_content_digest $validation_report $validation_meminfo)
let validation_result = (with-env {
  PATH: ([$validation_bin] ++ $env.PATH)
  USER: "tester"
  NUC_TEST_FLOCK_MARKER: $validation_flock_marker
  NUC_TEST_GATE_INVOCATIONS: $validation_gate_invocations
  NUC_TEST_NIX_CONFIG: $validation_nix_config
  GIT_CONFIG_COUNT: "1"
  GIT_CONFIG_KEY_0: "core.hooksPath"
  GIT_CONFIG_VALUE_0: $validation_hooks
} { ^bash -c $validation_command | complete })
assert equal $validation_result.exit_code 1 "validation must fail if any gate fails"
let validation_summary = (open ($validation_report | path join "summary.tsv"))
assert equal ($validation_summary | where gate == "full" | get 0.status) 3
assert equal ($validation_summary | where gate == "full" | get 0.log_status) 0
assert equal ($validation_summary | where gate == "nixos" | get 0.status) 0
assert equal ($validation_summary | where gate == "flake-check" | get 0.status) 5
let validation_result_record = (open ($validation_report | path join "result.tsv"))
assert equal $validation_result_record.outcome.0 "gates"
assert equal (^git -C $validation_source config core.hooksPath | str trim) "/dev/null" "synthetic repository must disable inherited hooks"
assert equal (open --raw $validation_flock_marker) "called"
assert ((open --raw $validation_nix_config) | str contains "max-jobs = 1")
assert ($validation_result.stdout | str contains "NUC_VALIDATION_REPORT_DIR=")
assert equal (^git -C $validation_source rev-parse HEAD^{tree} | str trim) $validation_content_digest

let low_memory_source = ($temp_dir | path join "low-memory-source")
let low_memory_report = ($validation_report_root | path join "low-memory-report")
let low_memory_meminfo = ($temp_dir | path join "low-memory-meminfo")
let low_memory_gate_invocations = ($temp_dir | path join "low-memory-gate-invocations")
mkdir ($low_memory_source | path join "scripts")
mkdir $low_memory_report
"" | save ($low_memory_source | path join "scripts" "validation.py")
"MemAvailable:   16777215 kB\n" | save $low_memory_meminfo
^git -C $low_memory_source init --quiet --initial-branch fixture
^git -C $low_memory_source add --force --all
let low_memory_content_digest = (^git -C $low_memory_source write-tree | str trim)
rm -rf ($low_memory_source | path join ".git")
open --raw $"($validation_report).summary-template" | save ($low_memory_report | path join "summary.tsv")
"state\ttimestamp\tstatus\toutcome\tdetail\nqueued\tnow\t\t\t\n" | save ($low_memory_report | path join "state.tsv")
let low_memory_result = (with-env {
  PATH: ([$validation_bin] ++ $env.PATH)
  NUC_TEST_FLOCK_MARKER: $validation_flock_marker
  NUC_TEST_GATE_INVOCATIONS: $low_memory_gate_invocations
  NUC_TEST_NIX_CONFIG: $validation_nix_config
} { ^bash -c (nuc-worktree-validation-command $low_memory_source $low_memory_content_digest $low_memory_report $low_memory_meminfo) | complete })
assert equal $low_memory_result.exit_code 1 "validation must fail closed when host memory headroom is too low"
assert not ($low_memory_gate_invocations | path exists) "low host headroom must prevent evaluator clients and daemon-backed builds from starting"
let low_memory_summary = (open ($low_memory_report | path join "summary.tsv"))
assert equal ($low_memory_summary | get status) [75 75 75]
assert ((open --raw ($low_memory_report | path join "full.log")) | str contains "gate not started because its host memory preflight failed")

let validation_finalizer = (nuc-worktree-validation-finalizer-command $validation_source tester $validation_report $temp_dir)
let validation_finalizer_result = (with-env {SERVICE_RESULT: "exit-code", EXIT_CODE: "exited", EXIT_STATUS: "1"} {
  ^bash -c $validation_finalizer | complete
})
assert equal $validation_finalizer_result.exit_code 1
let validation_state = (open ($validation_report | path join "state.tsv"))
assert equal ($validation_state | get state) ["queued" "running" "failed"]
assert equal ($validation_state | last | get outcome) "gates"
assert not (($validation_source | path join ".nuc-deploy-active") | path exists) "service finalization must own lease release"

let setup_source = ($temp_dir | path join "validation-setup-failure")
let setup_report = ($validation_report_root | path join "setup-failure")
mkdir ($setup_source | path join "bin")
mkdir ($setup_source | path join "scripts")
mkdir $setup_report
^cp $snapshot_pruner ($setup_source | path join "bin" "prune-nuc-deploy-snapshots")
"active" | save ($setup_source | path join ".nuc-deploy-active")
"" | save ($setup_source | path join "scripts" "validation.py")
open --raw $"($validation_report).summary-template" | save ($setup_report | path join "summary.tsv")
"state\ttimestamp\tstatus\toutcome\tdetail\nqueued\tnow\t\t\t\n" | save ($setup_report | path join "state.tsv")
let setup_result = (with-env {
  PATH: ([$validation_bin] ++ $env.PATH)
  NUC_TEST_FLOCK_MARKER: $validation_flock_marker
  NUC_TEST_GIT_SETUP_FAILURE: "1"
} { ^bash -c (nuc-worktree-validation-command $setup_source "0000000000000000000000000000000000000000" $setup_report $validation_meminfo) | complete })
assert equal $setup_result.exit_code 1
let setup_result_record = (open ($setup_report | path join "result.tsv"))
assert equal ($setup_result_record | get outcome.0) "setup"
assert (($setup_result_record | get detail.0) | str contains "snapshot digest mismatch") "digest mismatch must be a durable setup failure"
let setup_finalizer_result = (with-env {SERVICE_RESULT: "exit-code", EXIT_CODE: "exited", EXIT_STATUS: "1"} {
  ^bash -c (nuc-worktree-validation-finalizer-command $setup_source tester $setup_report $temp_dir) | complete
})
assert equal $setup_finalizer_result.exit_code 1
assert equal (open ($setup_report | path join "state.tsv") | last | get outcome) "setup"

let logging_source = ($temp_dir | path join "validation-logging-failure")
let logging_report = ($validation_report_root | path join "logging-failure")
mkdir ($logging_source | path join "scripts")
mkdir $logging_report
"" | save ($logging_source | path join "scripts" "validation.py")
^git -C $logging_source init --quiet --initial-branch fixture
^git -C $logging_source add --force --all
let logging_content_digest = (^git -C $logging_source write-tree | str trim)
rm -rf ($logging_source | path join ".git")
"state\ttimestamp\tstatus\toutcome\tdetail\nqueued\tnow\t\t\t\n" | save ($logging_report | path join "state.tsv")
open --raw $"($validation_report).summary-template" | save ($logging_report | path join "summary.tsv")
let fake_tee = r#'
#!__BASH__
cat >/dev/null
exit 12
'#
$fake_tee | str trim --left | str replace "__BASH__" $bash_path | save ($validation_bin | path join "tee")
^chmod +x ($validation_bin | path join "tee")
let logging_result = (with-env {
  PATH: ([$validation_bin] ++ $env.PATH)
  NUC_TEST_FLOCK_MARKER: $validation_flock_marker
  NUC_TEST_GATE_INVOCATIONS: $validation_gate_invocations
  NUC_TEST_NIX_CONFIG: $validation_nix_config
} { ^bash -c (nuc-worktree-validation-command $logging_source $logging_content_digest $logging_report $validation_meminfo) | complete })
assert equal $logging_result.exit_code 1
assert equal (open ($logging_report | path join "result.tsv") | get outcome.0) "logging"
assert equal (open ($logging_report | path join "summary.tsv") | get log_status) [12 12 12]
rm ($validation_bin | path join "tee")

let cleanup_source = ($temp_dir | path join "validation-cleanup-failure")
let cleanup_report = ($validation_report_root | path join "cleanup-failure")
mkdir ($cleanup_source | path join "bin")
mkdir $cleanup_report
"exit 23" | save ($cleanup_source | path join "bin" "prune-nuc-deploy-snapshots")
"active" | save ($cleanup_source | path join ".nuc-deploy-active")
"state\ttimestamp\tstatus\toutcome\tdetail\nqueued\tnow\t\t\t\nrunning\tnow\t\t\t\n" | save ($cleanup_report | path join "state.tsv")
"outcome\tstatus\tdetail\nsuccess\t0\tall validation gates passed\n" | save ($cleanup_report | path join "result.tsv")
let cleanup_finalizer_result = (with-env {SERVICE_RESULT: "success", EXIT_CODE: "exited", EXIT_STATUS: "0"} {
  ^bash -c (nuc-worktree-validation-finalizer-command $cleanup_source tester $cleanup_report $temp_dir) | complete
})
assert equal $cleanup_finalizer_result.exit_code 1 "cleanup failure after successful gates must fail the service"
assert equal (open ($cleanup_report | path join "state.tsv") | last | get outcome) "cleanup"
assert not (($cleanup_source | path join ".nuc-deploy-active") | path exists) "pruning failure must not retain the released lease"

let interrupted_source = ($temp_dir | path join "validation-interrupted")
let interrupted_report = ($validation_report_root | path join "interrupted")
mkdir ($interrupted_source | path join "bin")
mkdir $interrupted_report
^cp $snapshot_pruner ($interrupted_source | path join "bin" "prune-nuc-deploy-snapshots")
"active" | save ($interrupted_source | path join ".nuc-deploy-active")
"state\ttimestamp\tstatus\toutcome\tdetail\nqueued\tnow\t\t\t\nrunning\tnow\t\t\t\n" | save ($interrupted_report | path join "state.tsv")
let interrupted_result = (with-env {SERVICE_RESULT: "signal", EXIT_CODE: "killed", EXIT_STATUS: "TERM"} {
  ^bash -c (nuc-worktree-validation-finalizer-command $interrupted_source tester $interrupted_report $temp_dir) | complete
})
assert equal $interrupted_result.exit_code 1
assert equal (open ($interrupted_report | path join "state.tsv") | last | get outcome) "interrupted"
assert not (($interrupted_source | path join ".nuc-deploy-active") | path exists)

let rejected_source = ($temp_dir | path join "validation-rejected")
let rejected_report = ($validation_report_root | path join "rejected")
let rejected_bin = ($temp_dir | path join "validation-rejected-bin")
mkdir ($rejected_source | path join "bin")
mkdir $rejected_bin
^cp $snapshot_pruner ($rejected_source | path join "bin" "prune-nuc-deploy-snapshots")
"active" | save ($rejected_source | path join ".nuc-deploy-active")
let fake_systemctl = r#'
#!__BASH__
printf 'not-found\n'
'#
$fake_systemctl | str trim --left | str replace "__BASH__" $bash_path | save ($rejected_bin | path join "systemctl")
^chmod +x ($rejected_bin | path join "systemctl")
let rejected_unit = "nuc-validation-60000000-0000-0000-0000-000000000000.service"
let rejected_submission = (nuc-worktree-validation-submission-command $rejected_source $source_revision $validation_content_digest $rejected_report $rejected_unit tester "exit 42" $temp_dir)
let rejected_result = (with-env {PATH: ([$rejected_bin] ++ $env.PATH)} { ^bash -c $rejected_submission | complete })
assert equal $rejected_result.exit_code 1
assert equal (open ($rejected_report | path join "unit.txt") | str trim) $rejected_unit
assert equal (open ($rejected_report | path join "state.tsv") | last | get outcome) "submission"
let rejected_provenance = (open --raw ($rejected_report | path join "provenance.txt"))
assert ($rejected_provenance | str contains $"content_digest=git-tree:($validation_content_digest)")
assert ($rejected_provenance | str contains "evaluator_memory_boundary=user service: MemoryHigh=10G MemoryMax=12G")
assert ($rejected_provenance | str contains "builder_memory_boundary=none: system nix-daemon builders and KVM guests run outside the user service cgroup")
assert not (($rejected_source | path join ".nuc-deploy-active") | path exists) "definite submission rejection must release its lease"

let uncertain_source = ($temp_dir | path join "validation-submission-uncertain")
let uncertain_report = ($validation_report_root | path join "submission-uncertain")
mkdir ($uncertain_source | path join "bin")
^cp $snapshot_pruner ($uncertain_source | path join "bin" "prune-nuc-deploy-snapshots")
"active" | save ($uncertain_source | path join ".nuc-deploy-active")
let fake_loaded_systemctl = r#'
#!__BASH__
printf 'loaded\n'
'#
$fake_loaded_systemctl | str trim --left | str replace "__BASH__" $bash_path | save --force ($rejected_bin | path join "systemctl")
let uncertain_submission = (nuc-worktree-validation-submission-command $uncertain_source $source_revision $validation_content_digest $uncertain_report "nuc-validation-70000000-0000-0000-0000-000000000000.service" tester "exit 42" $temp_dir)
let uncertain_result = (with-env {PATH: ([$rejected_bin] ++ $env.PATH)} { ^bash -c $uncertain_submission | complete })
assert equal $uncertain_result.exit_code 42
assert (($uncertain_source | path join ".nuc-deploy-active") | path exists) "uncertain submission must preserve a lease that a service may own"
assert equal (open ($uncertain_report | path join "state.tsv") | last | get state) "queued"
"test" | save ($source_dir | path join "flake.nix")
"ignored.txt\n.pi/runtime/\nconfig/jj/config.toml\n.nuc-deploy-active\n" | save ($source_dir | path join ".gitignore")
"ignored" | save ($source_dir | path join "ignored.txt")
mkdir ($source_dir | path join "config" "jj")
mkdir ($source_dir | path join ".pi" "runtime")
"tracked ignored config" | save ($source_dir | path join "config" "jj" "config.toml")
"tracked Pi source" | save ($source_dir | path join ".pi" "tracked.txt")
"ignored Pi runtime" | save ($source_dir | path join ".pi" "runtime" "session.json")
"archived lease" | save ($source_dir | path join ".nuc-deploy-active")
^cp $revision_writer ($source_dir | path join "bin" "write-nuc-deploy-revision")
^git -C $source_dir init --quiet --initial-branch main
^git -C $source_dir add flake.nix .gitignore bin/write-nuc-deploy-revision .pi/tracked.txt
^git -C $source_dir add --force config/jj/config.toml
^git -C $source_dir -c user.name=Test -c user.email=test@example.invalid commit --quiet -m fixture
require-clean-rollout-repository $source_dir "fixture"
"dirty" | save ($source_dir | path join "rollout-dirty.txt")
let dirty_rollout_repository_blocked = (try {
  require-clean-rollout-repository $source_dir "fixture"
  false
} catch {|err|
  $err.msg | str contains "fixture repository is dirty"
})
assert $dirty_rollout_repository_blocked
rm ($source_dir | path join "rollout-dirty.txt")
let fixture_revision = (^git -C $source_dir rev-parse HEAD | str trim)
^git -C $source_dir update-ref refs/remotes/origin/main $fixture_revision
"mutated after status could have been checked" | save --force ($source_dir | path join "flake.nix")
^git -C $source_dir update-index --assume-unchanged flake.nix

let detected_clean_source = (nuc-deploy-source $source_dir)
assert equal $detected_clean_source.head $fixture_revision
assert equal $detected_clean_source.base $fixture_revision
assert not $detected_clean_source.dirty
mkdir $clean_destination_dir
"active" | save ($clean_destination_dir | path join ".nuc-deploy-active")
let clean_content_digest = (nuc-worktree-sync $source_dir $clean_destination_dir $fixture_revision $detected_clean_source.dirty)

assert (($clean_destination_dir | path join "bin" "write-nuc-deploy-revision") | path exists) "clean snapshots must include the tracked revision writer"
assert (($clean_destination_dir | path join "config" "jj" "config.toml") | path exists) "clean snapshots must include tracked ignored source"
assert (($clean_destination_dir | path join ".pi" "tracked.txt") | path exists) "clean snapshots must include tracked Pi source"
assert not (($clean_destination_dir | path join ".pi" "runtime" "session.json") | path exists) "clean snapshots must omit ignored untracked Pi runtime state"
assert equal (open --raw ($clean_destination_dir | path join ".nuc-deploy-active")) "active" "clean archive extraction must preserve the runtime lease"
let marker_command = (nuc-worktree-revision-command $clean_destination_dir $fixture_revision)
let marker_result = (^bash -c $marker_command | complete)
assert equal $marker_result.exit_code 0

assert not (($clean_destination_dir | path join ".git") | path exists) "worktree Git metadata must not be synced"
assert (($clean_destination_dir | path join "flake.nix") | path exists) "tracked worktree contents must still be synced"
assert not (($clean_destination_dir | path join "ignored.txt") | path exists) "clean snapshots must exclude ignored content"
assert equal (open --raw ($clean_destination_dir | path join "flake.nix")) (^git -C $source_dir show HEAD:flake.nix) "clean snapshots must materialize committed blobs, not assume-unchanged worktree content"
assert equal $clean_content_digest (^git -C $source_dir rev-parse $"($fixture_revision)^{tree}" | str trim)
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
let dirty_content_digest = (nuc-worktree-sync $source_dir $dirty_destination_dir $fixture_revision $detected_dirty_source.dirty)
assert (($dirty_destination_dir | path join "untracked.txt") | path exists) "dirty build snapshots must include the tested worktree content"
assert equal (open --raw ($dirty_destination_dir | path join "flake.nix")) "mutated after status could have been checked" "dirty snapshots must capture tracked worktree bytes despite assume-unchanged flags"
assert equal (open --raw ($dirty_destination_dir | path join "config" "jj" "config.toml")) "tracked ignored config" "dirty snapshots must preserve tracked ignored source"
assert equal (open --raw ($dirty_destination_dir | path join ".pi" "tracked.txt")) "tracked Pi source" "dirty snapshots must preserve tracked Pi source"
assert not (($dirty_destination_dir | path join ".pi" "runtime" "session.json") | path exists) "dirty snapshots must omit ignored untracked Pi runtime state"
assert not (($dirty_destination_dir | path join "ignored.txt") | path exists) "dirty snapshots must omit ignored untracked root state"
assert not (($dirty_destination_dir | path join ".git") | path exists) "dirty snapshots must still exclude Git metadata"
assert (($dirty_destination_dir | path join ".nuc-deploy-active") | path exists) "dirty snapshot transfer must preserve the destination-only active lease"
assert equal (open --raw ($dirty_destination_dir | path join ".nuc-deploy-active")) "active" "dirty snapshot transfer must not overwrite the destination-owned lease"

let dirty_validation_report = ($validation_report_root | path join "dirty-report")
mkdir $dirty_validation_report
open --raw $"($validation_report).summary-template" | save ($dirty_validation_report | path join "summary.tsv")
"state\ttimestamp\tstatus\toutcome\tdetail\nqueued\tnow\t\t\t\n" | save ($dirty_validation_report | path join "state.tsv")
let dirty_validation_result = (with-env {
  PATH: ([$validation_bin] ++ $env.PATH)
  NUC_TEST_FLOCK_MARKER: $validation_flock_marker
  NUC_TEST_GATE_INVOCATIONS: $validation_gate_invocations
  NUC_TEST_NIX_CONFIG: $validation_nix_config
} { ^bash -c (nuc-worktree-validation-command $dirty_destination_dir $dirty_content_digest $dirty_validation_report $validation_meminfo) | complete })
assert equal $dirty_validation_result.exit_code 1 "fixture gates still fail after exact dirty snapshot reconstruction"
assert equal (^git -C $dirty_destination_dir rev-parse HEAD^{tree} | str trim) $dirty_content_digest "synthetic Git reconstruction must preserve the transferred source tree"
assert equal (^git -C $dirty_destination_dir ls-files config/jj/config.toml | str trim) "config/jj/config.toml"
assert equal (^git -C $dirty_destination_dir ls-files .pi/tracked.txt | str trim) ".pi/tracked.txt"

let mutation_destination = ($temp_dir | path join "mutation-synced")
let mutation_bin = ($temp_dir | path join "mutation-bin")
let mutation_marker = ($temp_dir | path join "mutation-fired")
mkdir $mutation_destination
mkdir $mutation_bin
let real_git = (which git | get 0.path)
let mutating_git = r#'
#!__BASH__
if [[ " $* " == *" archive "* ]] && [[ ! -e "$NUC_TEST_MUTATION_MARKER" ]]; then
  printf 'changed during transfer\n' > "$NUC_TEST_MUTATION_PATH"
  : > "$NUC_TEST_MUTATION_MARKER"
fi
exec "$NUC_TEST_REAL_GIT" "$@"
'#
$mutating_git | str trim --left | str replace "__BASH__" $bash_path | save ($mutation_bin | path join "git")
^chmod +x ($mutation_bin | path join "git")
let source_mutation_blocked = (with-env {
  PATH: ([$mutation_bin] ++ $env.PATH)
  NUC_TEST_REAL_GIT: $real_git
  NUC_TEST_MUTATION_MARKER: $mutation_marker
  NUC_TEST_MUTATION_PATH: ($source_dir | path join "untracked.txt")
} {
  try {
    nuc-worktree-sync $source_dir $mutation_destination $fixture_revision true
    false
  } catch {|err|
    $err.msg | str contains "snapshot source changed while it was being transferred"
  }
})
assert $source_mutation_blocked "dirty snapshot transfer must detect source mutation"
assert ($mutation_marker | path exists) "mutation fixture must alter the source during archive transfer"

mkdir ($failed_prepare_source | path join "bin")
mkdir $failed_prepare_destination
^cp $snapshot_pruner ($failed_prepare_source | path join "bin" "prune-nuc-deploy-snapshots")
^git -C $failed_prepare_source init --quiet --initial-branch main
^git -C $failed_prepare_source add bin/prune-nuc-deploy-snapshots
^git -C $failed_prepare_source -c user.name=Test -c user.email=test@example.invalid commit --quiet -m fixture
let failed_prepare_revision = (^git -C $failed_prepare_source rev-parse HEAD | str trim)
"active" | save ($failed_prepare_destination | path join ".nuc-deploy-active")
let prepare_failed = (try {
  nuc-worktree-prepare $failed_prepare_source $failed_prepare_destination $failed_prepare_revision true tester "" $temp_dir
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

let service_prune_root = ($temp_dir | path join "service-prune-root")
let service_test_bin = ($temp_dir | path join "service-test-bin")
let live_unit = "nuc-validation-30000000-0000-0000-0000-000000000000.service"
let orphan_unit = "nuc-validation-40000000-0000-0000-0000-000000000000.service"
let live_snapshot = ($service_prune_root | path join $"dotfiles-worktree-tester-($source_revision)-clean-30000000-0000-0000-0000-000000000000")
let orphan_snapshot = ($service_prune_root | path join $"dotfiles-worktree-tester-($source_revision)-clean-40000000-0000-0000-0000-000000000000")
let mismatched_snapshot = ($service_prune_root | path join $"dotfiles-worktree-tester-($source_revision)-clean-50000000-0000-0000-0000-000000000000")
mkdir $live_snapshot $orphan_snapshot $mismatched_snapshot $service_test_bin
$"systemd-user-unit=($live_unit)" | save ($live_snapshot | path join ".nuc-deploy-active")
$"systemd-user-unit=($orphan_unit)" | save ($orphan_snapshot | path join ".nuc-deploy-active")
$"systemd-user-unit=($live_unit)" | save ($mismatched_snapshot | path join ".nuc-deploy-active")
^touch -d "2020-01-01 00:00:00 UTC" ($live_snapshot | path join ".nuc-deploy-active") ($orphan_snapshot | path join ".nuc-deploy-active") ($mismatched_snapshot | path join ".nuc-deploy-active")
let fake_prune_systemctl = r#'
#!__BASH__
if [[ "$1" == "--user" && "$2" == "is-active" && "$3" == "--quiet" && "$4" == "$NUC_TEST_LIVE_UNIT" ]]; then
  exit 0
fi
exit 4
'#
$fake_prune_systemctl | str trim --left | str replace "__BASH__" $bash_path | save ($service_test_bin | path join "systemctl")
^chmod +x ($service_test_bin | path join "systemctl")
let service_prune_result = (with-env {
  PATH: ([$service_test_bin] ++ $env.PATH)
  NUC_TEST_LIVE_UNIT: $live_unit
} { ^bash $snapshot_pruner $service_prune_root tester 0 | complete })
assert equal $service_prune_result.exit_code 0
assert ($live_snapshot | path exists) "a stale validation lease must survive while its service is queued or running"
assert ($live_snapshot | path join ".nuc-deploy-active" | path exists) "pruning must retain a live service-owned lease"
assert not ($orphan_snapshot | path exists) "a stale validation lease must be pruned after its service disappears"
assert not ($mismatched_snapshot | path exists) "a marker must not borrow another snapshot's live validation service"
rm -rf $temp_dir

print "hey nuc deploy mode tests passed"
