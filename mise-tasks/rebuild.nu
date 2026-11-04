#!/usr/bin/env -S nu --no-config-file
#MISE description="Rebuild the current host with activation guards"
#MISE raw=true
#MISE raw_args=true
#MISE alias='re'
use ../scripts/nu/common.nu *

def main [action: string = "switch", ...args: string] {
  let ctx = (context)
  check-flake-lock
  check-local-skill-leaks
  system-rebuild $ctx $action ...$args
  post-rebuild $ctx
}
