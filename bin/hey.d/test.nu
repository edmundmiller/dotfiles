#!/usr/bin/env -S nu --no-config-file
#MISE description="Test a host generation without making it the boot default"
#MISE raw=true
#MISE raw_args=true
use .lib/common.nu *

def main [...args: string] {
  let ctx = (context)
  system-rebuild $ctx "test" ...$args
}
