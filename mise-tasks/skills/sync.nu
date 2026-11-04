#!/usr/bin/env -S nu --no-config-file
#MISE description="Sync the skills pin and activate the host"
#MISE alias="skills-sync"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  cd $ctx.flake_dir
  ^nix flake update skills-catalog
  ^mise run rebuild
}
