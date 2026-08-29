#!/usr/bin/env nu

use std/assert
source ../hey.d/hermes.nu

let legacy = '"PID" = 1293;'
let current = '✓ Gateway is supervised by launchd (PID 1293)'

assert equal (gateway-status-pids $legacy | get 0.pid) "1293"
assert equal (gateway-status-pids $current | get 0.pid) "1293"
assert ((gateway-status-pids "Gateway is not running") | is-empty)

print "hey Hermes local status tests passed"
