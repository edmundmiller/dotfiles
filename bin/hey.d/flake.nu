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

# Python owns routing for both hey and CI. This command does not evaluate hosts
# merely to discover the checkout or platform.
def --wrapped "main check" [...args: string] {
  let root = ($env.FLAKE_DIR? | default (find-flake-up (pwd)))
  ^python3 ($root | path join "scripts/validation.py") ...$args
}

def "main show" [] {
  let ctx = (context)
  cd $ctx.flake_dir
  ^nix flake show
}
