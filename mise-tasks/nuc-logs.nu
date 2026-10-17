#!/usr/bin/env -S nu --no-config-file
#MISE description="Read NUC logs"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *
use ../scripts/nu/remote.nu *

def main [unit: string = "", lines: int = 50] {
  if ($unit | is-empty) {
    ^ssh $NUC_HOST $"sudo journalctl -n ($lines)"
  } else {
    ^ssh $NUC_HOST $"sudo journalctl -u ($unit) -n ($lines)"
  }
}
