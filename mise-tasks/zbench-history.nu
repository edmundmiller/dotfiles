#!/usr/bin/env -S nu --no-config-file
#MISE description="Show Zsh benchmark history"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  let history = ($ctx.flake_dir | path join "benchmarks" "zsh-bench" "history" $"($ctx.flake_host).tsv")
  if ($history | path exists) {
    open --raw $history
  } else {
    print "No history. Run: hey zbench-save"
  }
}
