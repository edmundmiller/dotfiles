#!/usr/bin/env -S nu --no-config-file
#MISE description="Show a NUC service"
#MISE alias="nuc-service"
#MISE raw=true
#MISE raw_args=true
use ../.lib/common.nu *
use ../.lib/remote.nu *

def main [service: string] {
  print $"Checking ($service) on NUC..."
  ^ssh $NUC_HOST $"systemctl status ($service)"
}
