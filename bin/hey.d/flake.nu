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

def "main check" [] {
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

    print ""
    print "==> Running treefmt formatting check..."
    let treefmt_check = (^nix build $".#checks.($ctx.nix_system).treefmt" --no-link | complete)
    if $treefmt_check.exit_code == 0 {
      print "✓ Formatting OK"
    } else {
      print "✗ Formatting check FAILED (run 'nix fmt' to fix)"
      if (($treefmt_check.stderr | str trim) | is-not-empty) {
        print -e $treefmt_check.stderr
      }
      $failed = true
    }

    print ""
    print "==> Running pre-commit hooks check..."
    let precommit_check = (^nix build $".#checks.($ctx.nix_system).pre-commit" --no-link | complete)
    if $precommit_check.exit_code == 0 {
      print "✓ Pre-commit hooks OK"
    } else {
      print "✗ Pre-commit check FAILED"
      if (($precommit_check.stderr | str trim) | is-not-empty) {
        print -e $precommit_check.stderr
      }
      $failed = true
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
