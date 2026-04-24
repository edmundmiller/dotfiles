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
    ^sudo $ctx.darwin_rebuild --rollback
  } else {
    ^nixos-rebuild --sudo --rollback switch
  }
}
