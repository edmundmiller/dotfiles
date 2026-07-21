use ./common.nu *

def agent-quality [...args: string] {
  let ctx = (context)
  with-env { AGENT_QUALITY_ROOT: $ctx.flake_dir } {
    ^agent-quality ...$args
  }
}

def --wrapped "main agent-review" [stage: string, ...args: string] {
  agent-quality review $stage ...$args
}

def --wrapped "main agent-start" [...args: string] {
  agent-quality start ...$args
}

def --wrapped "main agent-complete" [...args: string] {
  agent-quality complete ...$args
}

def --wrapped "main agent-audit-tests" [...paths: string] {
  agent-quality audit-tests ...$paths
}

def --wrapped "main agent-sweep" [...args: string] {
  agent-quality sweep ...$args
}

def --wrapped "main agent-finish" [...args: string] {
  agent-quality finish ...$args
}

def --wrapped "main agent-inventory" [...args: string] {
  agent-quality inventory ...$args
}

def "main agent-worklog-check" [path: string] {
  agent-quality validate-worklog $path
}
