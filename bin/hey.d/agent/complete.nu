#!/usr/bin/env -S nu --no-config-file
#MISE description="Complete an agent task receipt"
#MISE alias="agent-complete"
#MISE raw=true
#MISE raw_args=true

def --wrapped main [--help(-h), ...args: string] {
  if $help { help main; return }
  ^agent-run complete ...$args
}
