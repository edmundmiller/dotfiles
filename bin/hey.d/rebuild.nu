use ./common.nu *

def "main rebuild" [action: string = "switch", ...args: string] {
  let ctx = (context)
  fail-if-moshi-client-rebuild $ctx $action
  check-flake-lock
  check-local-skill-leaks
  system-rebuild $action ...$args
  post-rebuild
}

def "main re" [action: string = "switch", ...args: string] {
  main rebuild $action ...$args
}

def "main test" [...args: string] {
  let ctx = (context)
  fail-if-moshi-client-rebuild $ctx "test"
  system-rebuild "test" ...$args
}

def "main rollback" [] {
  let ctx = (context)
  if (is-darwin) {
    with-sudo-path { ^sudo $ctx.darwin_rebuild --rollback }
  } else {
    with-sudo-path { ^nixos-rebuild --sudo --rollback switch }
  }
}
