use ./common.nu *

def "main gc" [] {
  if (is-darwin) {
    ^sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations old
    ^sudo nix-collect-garbage -d
  }

  ^nix-collect-garbage -d
}

def "main repl" [] {
  let ctx = (context)
  cd $ctx.flake_dir

  let tempfile = "/tmp/dotfiles-repl.nix"
  let expr = ([ '(builtins.getFlake "' $ctx.flake_dir '")' ] | str join '')
  $expr | save --force $tempfile
  ^nix repl '<nixpkgs>' $tempfile
}

def "main search" [query: string] {
  ^nix search nixpkgs $query
}

def "main shell" [package: string] {
  ^nix shell $"nixpkgs#($package)"
}
