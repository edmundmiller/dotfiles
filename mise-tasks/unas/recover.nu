#!/usr/bin/env -S nu --no-config-file
#MISE description="Recover an installed UNAS system from a mounted root"
#MISE alias='unas-recover'
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *

def main [root: string, system: string] {
  let ctx = (context)
  ^bash ($ctx.flake_dir | path join "bin" "unas-recover") $root $system
  if $env.LAST_EXIT_CODE != 0 {
    error make {msg: "UNAS recovery installation failed; do not reboot"}
  }
}
