#!/usr/bin/env -S nu --no-config-file
#MISE description="Save a Zsh benchmark"
#MISE alias="zbench-save"
#MISE raw=true
#MISE raw_args=true
use ../.lib/zbench.nu *

def --wrapped main [--help(-h), ...args: string] {
  if $help { help main; return }
  zbench-run "save" ...$args
}
