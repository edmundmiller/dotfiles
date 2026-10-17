#!/usr/bin/env -S nu --no-config-file
#MISE description="Connect to the UNAS"
#MISE alias="unas-ssh"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *
use ../../scripts/nu/remote.nu *

def main [] {
  print "Connecting to UNAS..."
  ^ssh -t $UNAS_HOST
}
