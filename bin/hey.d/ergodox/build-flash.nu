#!/usr/bin/env -S nu --no-config-file
#MISE description="Build and flash Ergodox firmware"
#MISE alias="ergodox-build-flash"
#MISE raw=true
#MISE raw_args=true

def main [] {
  ^mise run ergodox:build
  ^mise run ergodox:flash
}
