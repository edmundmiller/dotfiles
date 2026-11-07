#!/usr/bin/env -S nu --no-config-file
#MISE description="Rebuild the NUC"
#MISE alias="rebuild-nuc"
#MISE raw=true
#MISE raw_args=true
use ../.lib/common.nu *
use ../.lib/remote.nu *

def main [] {
  ^mise run nuc
}
