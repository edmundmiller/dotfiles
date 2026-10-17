#!/usr/bin/env -S nu --no-config-file
#MISE description="Compatibility entrypoint for changed-source validation"
#MISE raw=true
#MISE raw_args=true
#MISE hide=true
use ../scripts/nu/common.nu *

def main [...args: string] {
  let ctx = (context)
  cd $ctx.flake_dir
  ^./bin/qa-changed ...$args
}
