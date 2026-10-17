#!/usr/bin/env -S nu --no-config-file
#MISE description="Show a NUC service"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *
use ../scripts/nu/remote.nu *

def main [service: string] {
  print $"Checking ($service) on NUC..."
  ^ssh $NUC_HOST $"systemctl status ($service)"
}
