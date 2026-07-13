use ./common.nu *

def require-success [label: string, result: record] {
  if $result.exit_code != 0 {
    let detail = ([$result.stdout $result.stderr] | str join "\n" | str trim)
    error make {msg: $"($label) failed: ($detail)"}
  }
}

def require-text [label: string, text: string, expected: string] {
  if not ($text | str contains $expected) {
    error make {msg: $"($label) missing expected text: ($expected)"}
  }
}

def "main hermes-local" [--smoke-only] {
  if not (is-darwin) {
    error make {msg: "hey hermes-local is Darwin-only"}
  }

  if not $smoke_only {
    main re
  }

  let manifest_path = ($env.HOME | path join ".config" "hermes-local" "manifest.json")
  if not ($manifest_path | path exists) {
    error make {msg: $"Hermes apply manifest missing: ($manifest_path)"}
  }
  let manifest = (open $manifest_path)

  let hermes_path = (^which hermes | str trim)
  let hermes_real = (^realpath $hermes_path | str trim)
  if $hermes_real != $manifest.hermes {
    error make {msg: $"Hermes binary drift: active=($hermes_real) expected=($manifest.hermes)"}
  }

  for profile in $manifest.profiles {
    let launcher = $"($profile)-hermes"
    let launcher_path = (^which $launcher | str trim)
    let launcher_real = (^realpath $launcher_path | str trim)
    let expected_launcher = ($manifest.launchers | get $profile)
    if $launcher_real != $expected_launcher {
      error make {msg: $"Hermes launcher drift for ($profile): active=($launcher_real) expected=($expected_launcher)"}
    }

    let rendered = (run-external $launcher "config" "check" | complete)
    require-success $"render and validate ($profile)" $rendered
    let marker = ($env.HOME | path join ".hermes" "profiles" $profile ".agents-workspace-revision")
    $manifest.agentsWorkspaceRevision | save --force $marker
    require-text $"profile revision ($profile)" (open --raw $marker) $manifest.agentsWorkspaceRevision
  }

  let profiles = (^hermes profile list | complete)
  require-success "Hermes profile inventory" $profiles
  for profile in $manifest.profiles {
    require-text "Hermes profile inventory" $profiles.stdout $profile
  }

  let codex = (^codex login status | complete)
  require-success "Codex login" $codex
  require-text "Codex login" ([$codex.stdout $codex.stderr] | str join "\n") "Logged in using ChatGPT"

  let install = (^orchestrator-hermes gateway install | complete)
  require-success "Orchestrator gateway install" $install
  let start = (^orchestrator-hermes gateway start | complete)
  require-success "Orchestrator gateway start" $start
  let gateway = (^orchestrator-hermes gateway status | complete)
  require-success "Orchestrator gateway status" $gateway
  let gateway_pid = ($gateway.stdout | parse --regex '"PID" = (?<pid>[0-9]+);')
  if ($gateway_pid | is-empty) {
    error make {msg: "Orchestrator gateway status missing a live PID"}
  }

  let dispatcher = (^orchestrator-hermes kanban dispatch --dry-run --json | complete)
  require-success "Kanban dispatcher" $dispatcher

  print $"PASS hermes-local\n  binary: ($hermes_real)\n  agents-workspace: ($manifest.agentsWorkspaceRevision)\n  profiles: ($manifest.profiles | str join ', ')\n  Codex: ChatGPT login active\n  gateway: running\n  Kanban dispatcher: healthy"
}
