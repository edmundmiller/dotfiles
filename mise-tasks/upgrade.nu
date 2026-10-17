#!/usr/bin/env -S nu --no-config-file
#MISE description="Update flake inputs and rebuild the host"
#MISE raw=true
#MISE raw_args=true

def main [] {
  ^mise run update
  ^mise run rebuild
}
