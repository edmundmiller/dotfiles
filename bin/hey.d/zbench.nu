use ./common.nu *

def zbench-run [mode: string, ...args: string] {
  let ctx = (context)
  let zbench_dir = ($ctx.flake_dir | path join "benchmarks" "zsh-bench")
  let zbench_report = ($ctx.flake_dir | path join "bin" "zbench-report")

  if ((^bash -lc "command -v zsh-bench >/dev/null 2>&1" | complete).exit_code != 0) {
    print "zsh-bench not on PATH; rebuild so modules.shell.zsh installs pkgs.my.zsh-bench"
    exit 1
  }

  print "==> Running zsh-bench (16 iterations)..."
  let raw = (^zsh-bench ...$args)

  let git_rev = (try { ^git -C $ctx.flake_dir rev-parse --short HEAD | str trim } catch { "unknown" })

  $raw | ^$zbench_report --mode $mode --host $ctx.flake_host --dir $zbench_dir --git-rev $git_rev
}

def --wrapped "main zbench" [...args] {
  zbench-run "run" ...$args
}

def --wrapped "main zbench-save" [...args] {
  zbench-run "save" ...$args
}

def --wrapped "main zbench-compare" [...args] {
  zbench-run "compare" ...$args
}

def --wrapped "main zbench-check" [...args] {
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
