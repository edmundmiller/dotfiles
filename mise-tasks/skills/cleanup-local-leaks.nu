#!/usr/bin/env -S nu --no-config-file
#MISE description="Remove project-local skills leaked into global skills"
#MISE alias="skills-cleanup-local-leaks"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  let global_dir = ($env.HOME | path join ".agents" "skills")
  let leaks = (local-skill-leaks)

  if ($leaks | is-empty) {
    print "no dotfiles project-local skill leaks found in ~/.agents/skills"
    return
  }

  for leak in $leaks {
    let target = ($global_dir | path join $leak)
    print $"removing leaked project-local skill from global target: ($leak)"
    ^chmod -R u+w $target
    rm -rf $target
  }

  print $"removed ($leaks | length) leaked project-local skills from ~/.agents/skills"
}
