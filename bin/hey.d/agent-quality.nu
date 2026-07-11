use ./common.nu *

def agent-quality [...args: string] {
  let ctx = (context)
  cd $ctx.flake_dir
  ^python3 bin/agent-quality ...$args
}

def --wrapped "main agent-review" [stage: string, ...args: string] {
  agent-quality review $stage ...$args
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
