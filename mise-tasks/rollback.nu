#!/usr/bin/env -S nu --no-config-file
#MISE description="Roll back the current host generation"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  if $ctx.os_name == "macos" {
    with-sudo-path { ^sudo $ctx.darwin_rebuild --rollback }
  } else {
    with-sudo-path { ^nixos-rebuild --sudo --rollback switch }
  }
}
