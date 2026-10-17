#!/usr/bin/env -S nu --no-config-file
#MISE description="Log in to Scintillate"
#MISE alias="login-scintillate"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *
use ../../scripts/nu/remote.nu *

def main [] {
  let script = (scintillate-login-script)
  let local_hostname = (^hostname -s | str trim)

  if $local_hostname == $NUC_HOST {
    ^bash -lc $script
  } else {
    print $"=== Connecting to ($NUC_HOST) for Scintillate Codex login ==="
    ^ssh -t $NUC_HOST $script
  }
}
