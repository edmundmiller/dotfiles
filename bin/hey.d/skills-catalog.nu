use ./common.nu *

def "main skills-update" [] {
  let ctx = (context)
  cd ($ctx.flake_dir | path join "skills")
  ^nix flake update
}

def "main skills-sync" [] {
  let ctx = (context)
  cd ($ctx.flake_dir | path join "skills")
  ^nix flake lock --update-input dotfiles-repo

  cd $ctx.flake_dir
  ^nix flake update skills-catalog
  main rebuild
}

def "main skills-bump" [] {
  let ctx = (context)
  cd ($ctx.flake_dir | path join "skills")
  ^nix flake update

  cd $ctx.flake_dir
  main rebuild
}


def "main skills-cleanup-local-leaks" [] {
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
