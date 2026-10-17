#!/usr/bin/env -S nu --no-config-file
#MISE description="Log in to Betty"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *
use ../scripts/nu/remote.nu *

def main [] {
  let script = (betty-login-script)
  let local_hostname = (^hostname -s | str trim)

  if $local_hostname == $NUC_HOST {
    ^bash -lc $script
  } else {
    print $"=== Connecting to ($NUC_HOST) for Betty Codex login ==="
    ^ssh -t $NUC_HOST $script
  }
}
