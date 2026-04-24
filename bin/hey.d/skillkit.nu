use ./common.nu *

def "main skillkit-sync" [] {
  let ctx = (context)
  let bin = ($ctx.flake_dir | path join "bin" "skillkit-sync")
  DOTFILES=$ctx.flake_dir ^$bin
}
