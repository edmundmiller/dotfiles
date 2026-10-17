#!/usr/bin/env -S nu --no-config-file
#MISE description="Upgrade only Mole through Homebrew"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [] {
  if not (is-darwin) {
    error make {msg: "Mole upgrade is only supported on macOS"}
  }
  with-env {
    HOMEBREW_NO_AUTO_UPDATE: "1"
    HOMEBREW_NO_INSTALL_CLEANUP: "1"
    HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK: "1"
  } {
    ^/opt/homebrew/bin/brew upgrade homebrew/core/mole
    if $env.LAST_EXIT_CODE != 0 {
      error make {msg: "Mole upgrade failed; inspect Homebrew output before retrying"}
    }
  }
}
