#!/usr/bin/env -S nu --no-config-file
#MISE description="Dry-activate the NUC"
#MISE alias="nuc-test"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *
use ../../scripts/nu/remote.nu *

def main [] {
  ^mise run nuc -- dry-activate
}
