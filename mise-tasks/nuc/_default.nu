#!/usr/bin/env -S nu --no-config-file
#MISE description="Build, validate or activate the NUC with provenance guards"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *
use ../../scripts/nu/remote.nu *

def main [mode: string = "auto", worktree_mode: string = "switch"] {
  let ctx = (context)
  cd $ctx.flake_dir

  let local_hostname = (^hostname -s | str trim)
  let local_system = ((^nix eval --impure --raw --expr builtins.currentSystem | complete).stdout | str trim)

  if $mode == "local" {
    print $"=== NUC deploy mode: local from ($local_hostname) (($local_system)) ==="
    nuc-local-rebuild
    return
  }

  if ($mode == "wt") or ($mode == "worktree") {
    print $"=== NUC deploy mode: worktree ($worktree_mode) from ($local_hostname) (($local_system)) ==="
    ^mise run nuc:worktree -- $worktree_mode
    return
  }

  if $mode in $NUC_WORKTREE_MODES {
    print $"=== NUC deploy mode: worktree ($mode) from ($local_hostname) (($local_system)) ==="
    ^mise run nuc:worktree -- $mode
    return
  }

  if $mode != "auto" {
    print -e "error: hey nuc mode must be one of: auto, local, wt, worktree, dry-activate, test, switch, build, vm, validate"
    error make {msg: "invalid hey nuc mode"}
  }

  let deploy_mode = (nuc-deploy-mode $local_hostname)
  print $"=== NUC deploy mode: ($deploy_mode) from ($local_hostname) (($local_system)) ==="
  if $deploy_mode == "local" {
    nuc-local-rebuild
    return
  }

  print "=== evaluating and building on the NUC from a synced worktree ==="
  ^mise run nuc:worktree -- $worktree_mode
}
