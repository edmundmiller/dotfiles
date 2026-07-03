use ./common.nu *

def "main update" [...inputs: string] {
  let ctx = (context)
  cd $ctx.flake_dir

  if ($inputs | is-empty) {
    print "Updating all flake inputs..."
    ^nix flake update
  } else {
    print $"Updating flake inputs: ($inputs | str join ' ')"
    for input in $inputs {
      ^nix flake update $input
    }
  }
}

def "main u" [...inputs: string] {
  main update ...$inputs
}

def "main upgrade" [] {
  main update
  main rebuild
}

def path-in-check-scope [file: string, scopes: list<string>] {
  let normalized_scopes = ($scopes | each {|scope| $scope | str trim | str trim --right --char "/" } | where {|scope| $scope != "" })

  if ($normalized_scopes | is-empty) {
    true
  } else {
    $normalized_scopes | any {|scope| $file == $scope or ($file | str starts-with $"($scope)/") }
  }
}

def changed-check-files [
  --worktree # Include staged, unstaged, and untracked files.
  ...scopes: string
] {
  let ctx = (context)
  mut files = []

  let upstream_result = (^git -C $ctx.flake_dir rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' | complete)
  let base_ref = if $upstream_result.exit_code == 0 {
    $upstream_result.stdout | str trim
  } else {
    let origin_main = (^git -C $ctx.flake_dir rev-parse --verify origin/main | complete)
    if $origin_main.exit_code == 0 { "origin/main" } else { "" }
  }

  if ($base_ref | is-not-empty) {
    $files = ($files | append (^git -C $ctx.flake_dir diff --name-only $"($base_ref)...HEAD" | lines))
  }

  if $worktree {
    $files = ($files | append (^git -C $ctx.flake_dir diff --name-only --cached | lines))
    $files = ($files | append (^git -C $ctx.flake_dir diff --name-only | lines))
    $files = ($files | append (^git -C $ctx.flake_dir ls-files --others --exclude-standard | lines))
  }

  $files | flatten | where {|file| ($file | str trim) != "" } | uniq | sort | where {|file| path-in-check-scope $file $scopes }
}

def check-scope-label [scopes: list<string>] {
  if ($scopes | is-empty) { "changed files" } else { $scopes | str join ", " }
}

def "main check" [
  --worktree # Include staged, unstaged, and untracked files in formatting/pre-commit checks.
  ...paths: string # Optional path scopes for formatting and pre-commit checks.
] {

  let ctx = (context)
  cd $ctx.flake_dir

  if (is-darwin) {
    print "Running Darwin-compatible checks (skipping NixOS configs)..."
    mut failed = false

    print ""
    print "==> Checking child flake lock sync..."
    let child_inputs = (^jq -r '.nodes.root.inputs | keys[]' skills/flake.lock | lines | sort | str join "\n")
    let parent_child_inputs = (^jq -r '.nodes["skills-catalog"].inputs | keys[]' flake.lock | lines | sort | str join "\n")

    if $child_inputs == $parent_child_inputs {
      print "✓ Child flake locks synced"
    } else {
      print "✗ skills/flake.lock is out of sync with parent flake.lock!"
      print $"  Child inputs:  ($child_inputs)"
      print $"  Parent inputs: ($parent_child_inputs)"
      print "  Fix: nix flake update skills-catalog"
      $failed = true
    }

    print ""
    print $"==> Checking Darwin configuration: ($ctx.flake_host)"
    let darwin_eval = (^nix eval $".#darwinConfigurations.($ctx.flake_host).system" --apply 'x: "OK"' | complete)
    if $darwin_eval.exit_code == 0 {
      print "✓ Darwin configuration OK"
    } else {
      print "✗ Darwin configuration FAILED"
      if (($darwin_eval.stderr | str trim) | is-not-empty) {
        print -e $darwin_eval.stderr
      }
      $failed = true
    }

    let check_files = (changed-check-files --worktree=$worktree ...$paths)
    let check_scope = (check-scope-label $paths)
    let check_files_label = if ($check_files | is-empty) { $"no changed files under ($check_scope)" } else { $"($check_files | length) changed files under ($check_scope)" }

    print ""
    print $"==> Running treefmt formatting check \(($check_files_label)\)..."
    if ($check_files | is-empty) {
      print "✓ Formatting OK (no changed files)"
    } else {
      let treefmt_check = (^prek run treefmt --files ...$check_files --no-progress | complete)
      if $treefmt_check.exit_code == 0 {
        print "✓ Formatting OK"
      } else {
        print "✗ Formatting check FAILED (run 'nix fmt' to fix)"
        if (($treefmt_check.stdout | str trim) | is-not-empty) {
          print $treefmt_check.stdout
        }
        if (($treefmt_check.stderr | str trim) | is-not-empty) {
          print -e $treefmt_check.stderr
        }
        $failed = true
      }
    }

    print ""
    print $"==> Running pre-commit hooks check \(($check_files_label)\)..."
    if ($check_files | is-empty) {
      print "✓ Pre-commit hooks OK (no changed files)"
    } else {
      let precommit_check = (^prek run --stage pre-commit --skip treefmt --files ...$check_files --no-progress | complete)
      if $precommit_check.exit_code == 0 {
        print "✓ Pre-commit hooks OK"
      } else {
        print "✗ Pre-commit check FAILED"
        if (($precommit_check.stdout | str trim) | is-not-empty) {
          print $precommit_check.stdout
        }
        if (($precommit_check.stderr | str trim) | is-not-empty) {
          print -e $precommit_check.stderr
        }
        $failed = true
      }
    }

    print ""
    print "==> Running zunit shell tests..."
    let zunit_check = (^nix build $".#checks.($ctx.nix_system).zunit-tests" --no-link | complete)
    if $zunit_check.exit_code == 0 {
      print "✓ Shell tests OK"
    } else {
      print "✗ Shell tests FAILED"
      if (($zunit_check.stderr | str trim) | is-not-empty) {
        print -e $zunit_check.stderr
      }
      $failed = true
    }

    print ""
    if not $failed {
      print "✓ All Darwin checks passed!"
    } else {
      print -e "✗ Some checks failed. For full checks including NixOS configs, run on Linux."
      error make {msg: "Darwin check failed"}
    }
  } else {
    print "Running full flake check..."
    ^nix flake check
  }
}

def "main show" [] {
  let ctx = (context)
  cd $ctx.flake_dir
  ^nix flake show
}
