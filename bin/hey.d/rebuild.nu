use ./common.nu *

def "main rebuild" [action: string = "switch", ...args: string] {
  check-flake-lock
  system-rebuild $action ...$args
  post-rebuild
}

def "main re" [action: string = "switch", ...args: string] {
  main rebuild $action ...$args
}

def "main test" [...args: string] {
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
