#!/usr/bin/env -S nu --no-config-file
#MISE description="Publish agents-workspace changes, update its pin and optionally deploy"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *
use ../scripts/nu/remote.nu *

def main [
  dotfiles_msg: string = "chore: bump agents-workspace"
  --workspace: string = ""
  --deploy-mode: string = "switch"
] {
  let ctx = (context)
  let workspace = if ($workspace | is-empty) {
    $env.HOME | path join "src" "personal" "agents-workspace"
  } else {
    $workspace | path expand
  }
  let dotfiles = $ctx.flake_dir
  let validated_deploy_mode = (agents-rollout-deploy-mode $deploy_mode)

  require-clean-rollout-repository $workspace "agents-workspace"
  require-clean-rollout-repository $dotfiles "dotfiles"

  if $validated_deploy_mode != "none" {
    print "=== Verify NUC tailnet target ==="
    ^ssh $NUC_HOST 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
  }

  print "=== Push agents-workspace ==="
  cd $workspace
  ^git pull --rebase
  ^git push
  let workspace_revision = (^git rev-parse HEAD | str trim)

  print "=== Pin agents-workspace input ==="
  cd $dotfiles
  pin-agents-workspace-input ($dotfiles | path join "flake.nix") $workspace_revision
  let authenticated_nix_config = (github-nix-config)
  with-env { NIX_CONFIG: $authenticated_nix_config } {
    ^nix flake update agents-workspace
  }

  print "=== Commit + push dotfiles ==="
  let pin_changed = (^git diff --quiet -- flake.nix flake.lock | complete)
  if $pin_changed.exit_code == 0 {
    print "agents-workspace pin unchanged; skipping commit"
  } else {
    ^git add flake.nix flake.lock
    ^git commit -m $dotfiles_msg
  }
  ^git pull --rebase
  ^git push

  if $validated_deploy_mode == "none" {
    print "=== NUC deployment skipped (--deploy-mode none) ==="
    return
  }

  print "=== Build pinned dotfiles + agents-workspace on NUC ==="
  ^mise run nuc -- build

  if $validated_deploy_mode == "build" {
    print "=== NUC activation skipped (--deploy-mode build) ==="
    return
  }

  print $"=== Activate NUC with mode: ($validated_deploy_mode) ==="
  ^mise run nuc -- $validated_deploy_mode
}
