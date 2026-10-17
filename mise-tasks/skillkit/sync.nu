#!/usr/bin/env -S nu --no-config-file
#MISE description="Reinstall and patch Skillkit"
#MISE alias="skillkit-sync"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  let bin = ($ctx.flake_dir | path join "bin" "skillkit-sync")
  DOTFILES=$ctx.flake_dir ^$bin
}
