#!/usr/bin/env -S nu --no-config-file
#MISE description="Test a host generation without making it the boot default"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [...args: string] {
  let ctx = (context)
  fail-if-moshi-client-rebuild $ctx "test"
  system-rebuild $ctx "test" ...$args
}
