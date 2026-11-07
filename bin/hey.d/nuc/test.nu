#!/usr/bin/env -S nu --no-config-file
#MISE description="Dry-activate the NUC"
#MISE alias="nuc-test"
#MISE raw=true
#MISE raw_args=true
use ../.lib/common.nu *
use ../.lib/remote.nu *

def main [] {
  ^mise run nuc -- dry-activate
}
