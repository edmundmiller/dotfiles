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
