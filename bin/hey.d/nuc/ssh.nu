#!/usr/bin/env -S nu --no-config-file
#MISE description="Connect to the NUC"
#MISE alias="nuc-ssh"
#MISE raw=true
#MISE raw_args=true
use ../.lib/common.nu *
use ../.lib/remote.nu *

def main [] {
  print "Connecting to NUC..."
  ^ssh -t $NUC_HOST
}
