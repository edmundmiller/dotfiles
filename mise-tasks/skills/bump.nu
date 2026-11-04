#!/usr/bin/env -S nu --no-config-file
#MISE description="Bump the parent skills input"
#MISE alias="skills-bump"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  cd ($ctx.flake_dir | path join "skills")
  ^nix flake update

  cd $ctx.flake_dir
  ^nix flake update skills-catalog
  ^mise run rebuild
}
