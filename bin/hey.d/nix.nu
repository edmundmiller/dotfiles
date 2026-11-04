use ./common.nu *

const DOTFILES_NIX_CACHE_BLOCK = '# BEGIN dotfiles binary caches
experimental-features = nix-command flakes
substituters = https://cache.nixos.org https://nix-community.cachix.org https://hyprland.cachix.org https://cosmic.cachix.org/ https://cache.numtide.com
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0H4HLrtLxA0fK5nQ1rG6Rt4p6MxY5U= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc= cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE= niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=
# END dotfiles binary caches'

def "main gc" [--keep-generations] {
  if $keep_generations {
    ^nix-store --gc
    if $env.LAST_EXIT_CODE != 0 {
      error make {msg: "Nix garbage collection failed"}
    }
    return
  }

  if (is-darwin) {
    ^sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations old
    ^sudo nix-collect-garbage -d
  }

  ^nix-collect-garbage -d
}

# Upgrade only Mole, without global Homebrew updates or automatic cleanup.
def "main mole-upgrade" [] {
  if not (is-darwin) {
    error make {msg: "Mole upgrade is only supported on macOS"}
  }
  with-env {
    HOMEBREW_NO_AUTO_UPDATE: "1"
    HOMEBREW_NO_INSTALL_CLEANUP: "1"
    HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK: "1"
  } {
    ^/opt/homebrew/bin/brew upgrade homebrew/core/mole
    if $env.LAST_EXIT_CODE != 0 {
      error make {msg: "Mole upgrade failed; inspect Homebrew output before retrying"}
    }
  }
}

# Preview-first Xcode cleanup and checksum-verified FG offload removal.
def --wrapped "main reclaim-mac-development" [...args: string] {
  let ctx = (context)
  ^python3 ($ctx.flake_dir | path join "scripts/reclaim-mac-development.py") ...$args
  if $env.LAST_EXIT_CODE != 0 {
    error make {msg: "Mac development cleanup failed; inspect the output before retrying"}
  }
}

# Prepare Metal in an existing Xcode, then select it without a full host rebuild.
def "main xcode-setup" [
  app: path # Path to an installed Xcode.app, including versioned app bundles
  --apply # Download missing Metal tools and select this Xcode system-wide
  --prompt-admin # Allow a macOS administrator dialog for xcode-select
  --install-to: path # Move the app to a shared location, without replacing an existing app
] {
  if not (is-darwin) {
    error make {msg: "Xcode setup is only supported on macOS"}
  }
  let developer = ($app | path expand | path join "Contents" "Developer")
  if not ($developer | path join "usr" "bin" "xcodebuild" | path exists) {
    error make {msg: $"No full Xcode found at ($app); pass the path to an installed Xcode.app"}
  }
  let destination = if $install_to == null { $app | path expand } else { $install_to | path expand }
  if $install_to != null and ($destination | path exists) {
    error make {msg: $"Destination already exists: ($destination); nothing will be replaced"}
  }
  let previous = (with-env {DEVELOPER_DIR: null} { ^/usr/bin/xcode-select -p } | str trim)
  print $"Current developer directory: ($previous)"
  print $"Requested developer directory: ($developer)"
  if $install_to != null { print $"Move Xcode to: ($destination)" }
  with-env {DEVELOPER_DIR: $developer} {
    ^/usr/bin/xcodebuild -version
    if $env.LAST_EXIT_CODE != 0 {
      error make {msg: "Cannot run this Xcode; open it and complete its first-launch setup"}
    }
    if not $apply {
      print "Dry run. Use --apply to prepare Metal and select this Xcode; --prompt-admin allows an administrator dialog."
      return
    }
    let first_launch = (do { ^/usr/bin/xcodebuild -checkFirstLaunchStatus } | complete)
    if $first_launch.exit_code != 0 {
      let license = (do { ^/usr/bin/xcodebuild -license check } | complete)
      if $license.exit_code != 0 {
        error make {msg: "Review and accept Xcode's license in the app, then rerun hey xcode-setup"}
      }
      if $prompt_admin {
        ^/usr/bin/osascript -e 'on run argv
          do shell script "/usr/bin/env " & quoted form of ("DEVELOPER_DIR=" & item 1 of argv) & " /usr/bin/xcodebuild -runFirstLaunch" with administrator privileges
        end run' $developer
      } else {
        ^sudo -n /usr/bin/env $"DEVELOPER_DIR=($developer)" /usr/bin/xcodebuild -runFirstLaunch
      }
      ^/usr/bin/xcodebuild -checkFirstLaunchStatus
    }
    let metal = (do { ^/usr/bin/xcrun --no-cache metal --version } | complete)
    if $metal.exit_code != 0 {
      ^/usr/bin/xcodebuild -downloadComponent MetalToolchain
      if $env.LAST_EXIT_CODE != 0 {
        error make {msg: "Metal installation failed; inspect the output and rerun hey xcode-setup"}
      }
    }
    ^/usr/bin/xcrun --no-cache metal --version
    if $env.LAST_EXIT_CODE != 0 {
      error make {msg: "Metal is still unavailable; open Xcode Settings > Components and install Metal Toolchain"}
    }
  }
  if not $apply { return }
  let selected = ($destination | path join "Contents" "Developer")
  if $install_to != null {
    if $prompt_admin {
      ^/usr/bin/osascript -e 'on run argv
        do shell script "/bin/test ! -e " & quoted form of (item 2 of argv) & " && /bin/mv " & quoted form of (item 1 of argv) & " " & quoted form of (item 2 of argv) with administrator privileges
      end run' ($app | path expand) $destination
    } else {
      ^sudo -n /bin/mv -n ($app | path expand) $destination
    }
    if $env.LAST_EXIT_CODE != 0 {
      error make {msg: "Xcode move failed; inspect source and destination before retrying"}
    }
  }
  if $previous != $selected {
    if $prompt_admin {
      ^/usr/bin/osascript -e 'on run argv
        do shell script "/usr/bin/xcode-select --switch " & quoted form of (item 1 of argv) with administrator privileges
      end run' $selected
    } else {
      ^sudo -n /usr/bin/xcode-select --switch $selected
    }
    if $env.LAST_EXIT_CODE != 0 {
      error make {msg: "Xcode selection failed; rerun with --apply --prompt-admin to allow an administrator dialog"}
    }
  }
  with-env {DEVELOPER_DIR: null} {
    ^/usr/bin/xcrun --no-cache metal --version
    if $env.LAST_EXIT_CODE != 0 {
      error make {msg: "The selected Xcode cannot run Metal; inspect xcode-select -p"}
    }
  }
  print $"Xcode selected. Previous developer directory for rollback: ($previous)"
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
