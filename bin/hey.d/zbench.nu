use ./common.nu *

def zbench-run [mode: string, ...args: string] {
  let ctx = (context)
  let zbench_dir = ($ctx.flake_dir | path join "benchmarks" "zsh-bench")
  let zbench_report = ($ctx.flake_dir | path join "bin" "zbench-report")

  let zbench = if ((^bash -lc "command -v zsh-bench >/dev/null 2>&1" | complete).exit_code == 0) {
    "zsh-bench"
  } else {
    ($ctx.flake_dir | path join "zsh-bench")
  }

  print "==> Running zsh-bench (16 iterations)..."
  let raw = if $zbench == "zsh-bench" {
    ^zsh-bench ...$args
  } else {
    ^$zbench ...$args
  }

  let git_rev = (try { ^git -C $ctx.flake_dir rev-parse --short HEAD | str trim } catch { "unknown" })

  $raw | ^$zbench_report --mode $mode --host $ctx.flake_host --dir $zbench_dir --git-rev $git_rev
}

def "main zbench" [...args: string] {
  zbench-run "run" ...$args
}

def "main zbench-save" [...args: string] {
  zbench-run "save" ...$args
}

def "main zbench-compare" [...args: string] {
  zbench-run "compare" ...$args
}

def "main zbench-check" [...args: string] {
  zbench-run "check" ...$args
}

def "main zbench-baseline" [] {
  let ctx = (context)
  let baseline = ($ctx.flake_dir | path join "benchmarks" "zsh-bench" $"($ctx.flake_host).json")
  if ($baseline | path exists) {
    open --raw $baseline
  } else {
    print "No baseline saved. Run: hey zbench-save"
  }
}

def "main zbench-history" [] {
  let ctx = (context)
  let history = ($ctx.flake_dir | path join "benchmarks" "zsh-bench" "history" $"($ctx.flake_host).tsv")
  if ($history | path exists) {
    open --raw $history
  } else {
    print "No history. Run: hey zbench-save"
  }
}
