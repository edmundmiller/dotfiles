#!/usr/bin/env -S nu --no-config-file
#MISE description="Record an agent task checkpoint"
#MISE alias="agent-checkpoint"
#MISE raw=true
#MISE raw_args=true

def --wrapped main [--help(-h), ...args: string] {
  if $help { help main; return }
  ^agent-run checkpoint ...$args
}
