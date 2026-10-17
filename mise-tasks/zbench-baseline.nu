#!/usr/bin/env -S nu --no-config-file
#MISE description="Show the Zsh benchmark baseline"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  let baseline = ($ctx.flake_dir | path join "benchmarks" "zsh-bench" $"($ctx.flake_host).json")
  if ($baseline | path exists) {
    open --raw $baseline
  } else {
    print "No baseline saved. Run: hey zbench-save"
  }
}
