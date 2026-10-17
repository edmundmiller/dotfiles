#!/usr/bin/env -S nu --no-config-file
#MISE description="Connect to the NUC"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *
use ../scripts/nu/remote.nu *

def main [] {
  print "Connecting to NUC..."
  ^ssh -t $NUC_HOST
}
