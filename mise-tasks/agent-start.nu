#!/usr/bin/env -S nu --no-config-file
#MISE description="Start an agent task receipt"
#MISE raw=true
#MISE raw_args=true

def --wrapped main [--help(-h), ...args: string] {
  if $help { help main; return }
  ^agent-run start ...$args
}
