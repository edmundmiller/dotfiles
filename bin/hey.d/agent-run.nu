def agent-run [...args: string] {
  ^agent-run ...$args
}

def --wrapped "main agent-start" [...args: string] {
  agent-run start ...$args
}

def --wrapped "main agent-adopt" [...args: string] {
  agent-run adopt ...$args
}

def --wrapped "main agent-checkpoint" [...args: string] {
  agent-run checkpoint ...$args
}

def --wrapped "main agent-complete" [...args: string] {
  agent-run complete ...$args
}

def --wrapped "main agent-sweep" [...args: string] {
  agent-run sweep ...$args
}
