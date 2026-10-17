#!/usr/bin/env -S nu --no-config-file
#MISE description="Inspect agent task receipts"
#MISE alias="agent-sweep"
#MISE raw=true
#MISE raw_args=true

def --wrapped main [--help(-h), ...args: string] {
  if $help { help main; return }
  ^agent-run sweep ...$args
}
