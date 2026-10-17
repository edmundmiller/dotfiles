#!/usr/bin/env -S nu --no-config-file
#MISE description="Rebuild the NUC"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *
use ../scripts/nu/remote.nu *

def main [] {
  ^mise run nuc
}
