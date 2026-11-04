#!/usr/bin/env -S nu --no-config-file
#MISE description="Run focused Zsh tests"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [...args: string] {
  let ctx = (context)
  cd $ctx.flake_dir

  if ((^bash -lc "command -v zunit >/dev/null 2>&1" | complete).exit_code != 0) {
    print -e "zunit not found. Install with: brew install zunit-zsh/zunit/zunit"
    error make {msg: "zunit not found"}
  }

  if ($args | is-not-empty) {
    ^zunit ...$args
  } else {
    let tests = (ls config/**/*.zunit | get name)
    for t in $tests {
      ^zunit $t
    }
  }
}
