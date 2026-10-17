#!/usr/bin/env -S nu --no-config-file
#MISE description="Update selected or all flake inputs"
#MISE raw=true
#MISE raw_args=true
#MISE alias='u'
use ../scripts/nu/common.nu *

def main [...inputs: string] {
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
