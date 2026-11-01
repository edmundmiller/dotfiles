use ./common.nu *

def "main rebuild" [action: string = "switch", ...args: string] {
  let ctx = (context)
  check-flake-lock
  check-local-skill-leaks
  system-rebuild $ctx $action ...$args
  post-rebuild $ctx
}

def "main re" [action: string = "switch", ...args: string] {
  main rebuild $action ...$args
}

def "main test" [...args: string] {
  let ctx = (context)
  system-rebuild $ctx "test" ...$args
}

def "main rollback" [] {
  let ctx = (context)
  if $ctx.os_name == "macos" {
    with-sudo-path { ^sudo $ctx.darwin_rebuild --rollback }
  } else {
    with-sudo-path { ^nixos-rebuild --sudo --rollback switch }
  }
}
