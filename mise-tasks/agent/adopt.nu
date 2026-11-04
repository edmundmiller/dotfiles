#!/usr/bin/env -S nu --no-config-file
#MISE description="Adopt an agent workspace"
#MISE alias="agent-adopt"
#MISE raw=true
#MISE raw_args=true

def --wrapped main [--help(-h), ...args: string] {
  if $help { help main; return }
  ^agent-run adopt ...$args
}
