export def require-success [label: string, result: record] {
  if $result.exit_code != 0 {
    let detail = ([$result.stdout $result.stderr] | str join "\n" | str trim)
    error make {msg: $"($label) failed: ($detail)"}
  }
}

export def require-text [label: string, text: string, expected: string] {
  if not ($text | str contains $expected) {
    error make {msg: $"($label) missing expected text: ($expected)"}
  }
}

export def gateway-status-pids [text: string] {
  let launchctl = ($text | parse --regex '"PID"\s*=\s*(?<pid>[0-9]+);')
  if not ($launchctl | is-empty) {
    return $launchctl
  }

  $text | parse --regex '\(PID\s+(?<pid>[0-9]+)\)'
}
