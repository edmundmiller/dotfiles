#!/usr/bin/env -S nu --no-config-file
#MISE description="Open a Nix REPL for this flake"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  cd $ctx.flake_dir

  let tempfile = "/tmp/dotfiles-repl.nix"
  let expr = ([ '(builtins.getFlake "' $ctx.flake_dir '")' ] | str join '')
  $expr | save --force $tempfile
  ^nix repl '<nixpkgs>' $tempfile
}
