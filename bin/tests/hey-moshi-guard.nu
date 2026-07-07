#!/usr/bin/env nu

use std/assert
source ../hey.d/common.nu

let macos_ctx = { os_name: "macos" }
let linux_ctx = { os_name: "linux" }

let blocked = (with-env { MOSHI_CLIENT: "1" } {
  try {
    fail-if-moshi-client-rebuild $macos_ctx "switch"
    false
  } catch {|err|
    ($err.msg | str contains "MOSHI_CLIENT=1") and ($err.msg | str contains "launchctl managername=Background")
  }
})
assert $blocked

with-env { MOSHI_CLIENT: "1" } {
  fail-if-moshi-client-rebuild $macos_ctx "build"
  fail-if-moshi-client-rebuild $linux_ctx "switch"
}

with-env { MOSHI_CLIENT: "" } {
  fail-if-moshi-client-rebuild $macos_ctx "switch"
}

print "hey Moshi guard tests passed"
