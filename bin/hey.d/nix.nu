use ./common.nu *

const DOTFILES_NIX_CACHE_BLOCK = '# BEGIN dotfiles binary caches
experimental-features = nix-command flakes
substituters = https://cache.nixos.org https://nix-community.cachix.org https://hyprland.cachix.org https://cosmic.cachix.org/ https://cache.numtide.com
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0H4HLrtLxA0fK5nQ1rG6Rt4p6MxY5U= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc= cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE= niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=
# END dotfiles binary caches'

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

# Install the small, explicit binary-cache trust bootstrap needed before the
# first managed rebuild. This intentionally does not set accept-flake-config,
# so arbitrary flakes cannot add their own caches later.
def "main setup-caches" [
  --apply # Write the managed block to /etc/nix/nix.conf and restart nix-daemon
] {
  let nix_conf = "/etc/nix/nix.conf"
  let marker = "# BEGIN dotfiles binary caches"

  if ($nix_conf | path exists) {
    let existing = (open --raw $nix_conf)
    if ($existing | str contains $marker) {
      print $"dotfiles cache block already present in ($nix_conf)"
      return
    }
  }

  print "This bootstraps only the dotfiles-approved Nix binary caches:"
  print "  - cache.nixos.org"
  print "  - nix-community.cachix.org"
  print "  - hyprland.cachix.org"
  print "  - cosmic.cachix.org"
  print "  - cache.numtide.com (llm-agents.nix)"
  print ""
  print "It does NOT enable accept-flake-config, so random flakes cannot add trusted caches."
  print ""

  if not $apply {
    print "Dry run. Re-run with `hey setup-caches --apply` to write:"
    print $"  ($nix_conf)"
    print ""
    print $DOTFILES_NIX_CACHE_BLOCK
    return
  }

  let answer = (input "Append this managed block to /etc/nix/nix.conf? Type 'yes' to continue: ")
  if $answer != "yes" {
    print "aborted"
    return
  }

  let block_file = (mktemp --tmpdir dotfiles-nix-caches.XXXXXX)
  $DOTFILES_NIX_CACHE_BLOCK | save --force $block_file

  ^sudo mkdir -p /etc/nix
  ^bash -c $"set -euo pipefail; sudo touch '($nix_conf)'; printf '\n' | sudo tee -a '($nix_conf)' >/dev/null; sudo cat '($block_file)' | sudo tee -a '($nix_conf)' >/dev/null; printf '\n' | sudo tee -a '($nix_conf)' >/dev/null"
  rm -f $block_file

  if (is-darwin) {
    ^sudo launchctl kickstart -k system/org.nixos.nix-daemon
  } else {
    ^sudo systemctl restart nix-daemon
  }

  print "Nix cache bootstrap complete. You can now run `hey re`."
}
