#!/usr/bin/env -S nu --no-config-file
#MISE description="Update the skills catalog"
#MISE alias="skills-update"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  cd ($ctx.flake_dir | path join "skills")
  ^nix flake update
}
