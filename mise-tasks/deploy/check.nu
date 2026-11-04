#!/usr/bin/env -S nu --no-config-file
#MISE description="Check the NUC deploy path with remote dry-activate"
#MISE alias="deploy-check"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *
use ../../scripts/nu/remote.nu *

def main [] {
  print "=== Checking NUC deploy path with remote dry-activate ==="
  ^mise run nuc -- dry-activate
}
