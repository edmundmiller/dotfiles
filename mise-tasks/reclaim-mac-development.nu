#!/usr/bin/env -S nu --no-config-file
#MISE description="Preview or apply targeted Mac development cleanup"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def --wrapped main [--help(-h), ...args: string] {
  if $help { help main; return }
  let ctx = (context)
  ^python3 ($ctx.flake_dir | path join "scripts/reclaim-mac-development.py") ...$args
  if $env.LAST_EXIT_CODE != 0 {
    error make {msg: "Mac development cleanup failed; inspect the output before retrying"}
  }
}
