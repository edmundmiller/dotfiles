#!/usr/bin/env -S nu --no-config-file
#MISE description="Benchmark Zsh startup"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/zbench.nu *

def --wrapped main [--help(-h), ...args: string] {
  if $help { help main; return }
  zbench-run "run" ...$args
}
