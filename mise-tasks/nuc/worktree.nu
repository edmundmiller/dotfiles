#!/usr/bin/env -S nu --no-config-file
#MISE description="Deploy an isolated NUC snapshot; defaults to dry-activate"
#MISE alias=["nuc-worktree", "nuc-wt"]
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *
use ../../scripts/nu/remote.nu *

def main [mode: string = "dry-activate", configuration: string = "nuc"] {
  validate-nuc-worktree-mode $mode
  let deploy_configuration = (nuc-worktree-configuration $configuration)
  let ctx = (context)
  let source = (nuc-deploy-source $ctx.flake_dir)
  require-clean-nuc-activation $source $mode
  let deploy_user = ($env.USER? | default "user")
  let remote_dir = (nuc-worktree-remote-dir $deploy_user $source)
  let revision = if $source.dirty { $"($source.head)-dirty" } else { $source.head }
  let prune_script = ($ctx.flake_dir | path join "bin" "prune-nuc-deploy-snapshots")
  let local_validation = ($mode == "validate") and ((^hostname -s | str trim) == $NUC_HOST)
  let target_host = if $local_validation { "" } else { $NUC_HOST }

  let target = if $local_validation { $remote_dir } else { $"($NUC_HOST):($remote_dir)" }
  print $"=== Syncing current worktree to NUC: ($ctx.flake_dir) -> ($target) ==="
  print $"NUC_WORKTREE_REMOTE_DIR=($remote_dir)"
  nuc-worktree-prune $prune_script $deploy_user $target_host
  if $local_validation {
    mkdir $remote_dir
    ^touch ($remote_dir | path join ".nuc-deploy-active")
  } else {
    ^ssh $NUC_HOST $"mkdir -p '($remote_dir)'"
    ^ssh $NUC_HOST $"touch '($remote_dir)/.nuc-deploy-active'"
  }
  let content_digest = (nuc-worktree-prepare $ctx.flake_dir $remote_dir $revision $source.dirty $deploy_user $target_host)

  if $mode == "validate" {
    let report_dir = (nuc-worktree-validation-report-dir $deploy_user $revision)
    let unit = (nuc-worktree-validation-unit $remote_dir)
    print "=== Queueing full, NixOS/KVM, and flake gates from synced worktree on NUC ==="
    print $"NUC_VALIDATION_REPORT_DIR=($report_dir)"
    print $"NUC_VALIDATION_UNIT=($unit)"
    nuc-worktree-claim-validation-lease $remote_dir $unit $target_host
    let command = (nuc-worktree-validation-command $remote_dir $content_digest $report_dir)
    let finalizer = (nuc-worktree-validation-finalizer-command $remote_dir $deploy_user $report_dir)
    let service_command = (nuc-worktree-validation-service-command $command $finalizer $unit)
    let submission_command = (nuc-worktree-validation-submission-command $remote_dir $revision $content_digest $report_dir $unit $deploy_user $service_command)
    if $local_validation {
      ^bash -c $submission_command
    } else {
      ^ssh $NUC_HOST $submission_command
    }
    return
  }

  if $mode == "vm" {
    print "=== Building NUC VM from synced worktree on NUC ==="
    let command = $"cd '($remote_dir)' && /run/wrappers/bin/sudo nix-private-github nix build .#nixosConfigurations.($deploy_configuration).config.system.build.vm --show-trace --accept-flake-config --max-jobs 1"
    ^ssh $NUC_HOST (nuc-worktree-lifecycle-command $remote_dir $deploy_user $command)
    return
  }

  print $"=== Running nixos-rebuild ($mode) for ($deploy_configuration) from synced worktree on NUC ==="
  if $mode == "build" {
    let command = $"cd '($remote_dir)' && /run/wrappers/bin/sudo nix-private-github nixos-rebuild build --flake .#($deploy_configuration) --show-trace --accept-flake-config --max-jobs 1"
    ^ssh $NUC_HOST (nuc-worktree-lifecycle-command $remote_dir $deploy_user $command)
  } else {
    let source_args = ((nuc-deploy-source-args $source) | str join " ")
    let command = $"cd '($remote_dir)' && /run/wrappers/bin/sudo nix-private-github ($source_args) nixos-rebuild ($mode) --flake .#($deploy_configuration) --show-trace --accept-flake-config --max-jobs 1"
    ^ssh $NUC_HOST (nuc-worktree-lifecycle-command $remote_dir $deploy_user $command)
    if ($mode == "switch") or ($mode == "test") {
      nuc-post-deploy-check false
    }
  }
}
