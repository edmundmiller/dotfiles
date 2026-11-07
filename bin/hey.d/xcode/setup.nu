#!/usr/bin/env -S nu --no-config-file
#MISE description="Prepare Metal and optionally select an installed Xcode"
#MISE alias='xcode-setup'
#MISE raw=true
#MISE raw_args=true
use ../.lib/common.nu *

def main [
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
