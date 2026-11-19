#!/usr/bin/env -S nu --no-config-file
#MISE description="Install the pinned tinyTouch Mac CLI and optionally pair HID"
#MISE raw=true
#MISE raw_args=true

# Keep the signed upstream bundle intact for macOS Keychain helper access.
const TINYTOUCH_VERSION = "0.1.35"
const TINYTOUCH_INSTALLER_SHA256 = "57b8c972045bfb1c811176112700a69817bab58ed055379d7287cdbcdcf09a4b"

def main [
  --pair # Interactively add this Mac as an HID computer, preserving fingerprints
  --port: string # Select a USB serial path when pairing multiple devices
] {
  if $nu.os-info.name != "macos" {
    error make {msg: "tinyTouch setup requires macOS; Meshify is not supported by the upstream helper"}
  }
  if $port != null and not $pair {
    error make {msg: "tinyTouch --port requires --pair"}
  }

  let install_dir = ($env.HOME | path join ".local" "bin")
  let cli = ($install_dir | path join "tinytouch")
  let expected = $"tinyTouch CLI ($TINYTOUCH_VERSION)"
  let installed = if ($cli | path exists) {
    let result = (^$cli --version | complete)
    $result.exit_code == 0 and ($result.stdout | str trim) == $expected
  } else { false }

  if not $installed {
    let release_root = $"https://github.com/ZimengXiong/tinyTouch/releases/download/v($TINYTOUCH_VERSION)"
    let installer = (mktemp --tmpdir tinytouch-install.XXXXXX)
    try {
      let download = (^curl --fail --silent --show-error --location --output $installer $"($release_root)/install.sh" | complete)
      if $download.exit_code != 0 {
        error make {msg: $"tinyTouch installer download failed; the installed CLI was not replaced\n($download.stderr | str trim)"}
      }
      if (open --raw $installer | hash sha256) != $TINYTOUCH_INSTALLER_SHA256 {
        error make {msg: "tinyTouch installer checksum mismatch; refusing to execute it"}
      }
      mkdir $install_dir
      with-env {TINYTOUCH_RELEASE_ROOT: $release_root, TINYTOUCH_INSTALL_DIR: $install_dir} {
        ^/bin/sh $installer
        if $env.LAST_EXIT_CODE != 0 {
          error make {msg: "tinyTouch installation failed; inspect the installer output before retrying"}
        }
      }
    } catch {|err|
      rm -f $installer
      error make {msg: $err.msg}
    }
    rm -f $installer
  }

  print $"($expected) is installed at ($cli)"
  if $pair {
    print "Use this Mac's password in the hidden prompt. Touch only when prompted."
    let port_args = if $port == null { [] } else { [--port $port] }
    ^$cli ...$port_args setup --mode hid --skip-enroll
    exit $env.LAST_EXIT_CODE
  }
  print "Run hey tinytouch-setup --pair in Terminal to save this Mac's password in Keychain and install its helper."
}
