export const DARWIN_REBUILD = "/run/current-system/sw/bin/darwin-rebuild"

export def find-flake-up [start: path] {
  mut dir = ($start | path expand)
  loop {
    if (($dir | path join "flake.nix") | path exists) {
      return $dir
    }

    let parent = ($dir | path dirname)
    if $parent == $dir {
      break
    }
    $dir = $parent
  }

  null
}

export def context [] {
  let flake_dir = ($env.MISE_PROJECT_ROOT? | default { find-flake-up (pwd) })
  if $flake_dir == null {
    error make {msg: "Run this task in the dotfiles checkout, or use mise --cd <checkout> run <task>"}
  }

  let hostname = (try { ^hostname -s | str trim } catch { "unknown" })
  let flake_host = if (($env.FLAKE_HOST? | default "") | is-not-empty) {
    $env.FLAKE_HOST
  } else {
    match $hostname {
      "Mac" => "MacTraitor-Pro"
      "mactraitor-pro" => "MacTraitor-Pro"
      "L19W56QXR4" => "Seqeratop"
      _ => $hostname
    }
  }

  let nix_system = (try { ^nix eval --raw --impure --expr 'builtins.currentSystem' | str trim } catch { "unknown" })

  {
    flake_dir: $flake_dir
    hostname: $hostname
    flake_host: $flake_host
    os_name: $nu.os-info.name
    nix_system: $nix_system
    darwin_rebuild: $DARWIN_REBUILD
  }
}

export def is-darwin [] {
  (context).os_name == "macos"
}

export def github-nix-config [] {
  let existing_nix_config = ($env.NIX_CONFIG? | default "")
  if (which gh | is-empty) {
    return $existing_nix_config
  }

  let token_result = (^gh auth token | complete)
  if $token_result.exit_code != 0 {
    return $existing_nix_config
  }

  let github_token = ($token_result.stdout | str trim)
  if ($github_token | is-empty) {
    return $existing_nix_config
  }

  if ($existing_nix_config | is-empty) {
    $"access-tokens = github.com=($github_token)"
  } else {
    $"($existing_nix_config)\naccess-tokens = github.com=($github_token)"
  }
}

export def with-sudo-path [body: closure] {
  let path = (sudo-path)
  if $path != "" {
    with-env { PATH: $path } { do $body }
  } else {
    do $body
  }
}

# Runs argv as root. Agent sessions have no terminal for sudo's password
# prompt, so when sudo has no cached credentials either, the command runs in a
# Rex pane beside the caller. Its output is copied back here and the pane is
# closed whether it succeeds or fails. HEY_REX=0 keeps the plain sudo call.
export def --wrapped run-sudo [...argv: string] {
  if not (sudo-wants-rex) {
    ^/usr/bin/sudo ...$argv
    return
  }
  let session = $env.REX_SESSION
  let anchor = if ($env.REX_BLOCK? | is-empty) { [] } else { [-b $env.REX_BLOCK] }
  print -e "hey: sudo needs a password; enter it in the Rex pane that opens beside this one."
  # --shell none skips the login shell, so pass the caller's PATH through sudo.
  let path = ([$env.PATH] | flatten | str join (char esep))
  # --keep-open leaves the pane for capture; Rex closes a successful one at exit.
  let run = (
    ^rex split -s $session ...$anchor --wait --keep-open --json --label "hey: sudo" --shell none -- /usr/bin/env $"PATH=($path)" /usr/bin/sudo ...$argv
    | complete
  )
  let block = ($run.stdout | from json | get -o block_ids.0)
  if $block != null {
    print (^rex capture -s $session -b $block --trim | complete).stdout
    ^rex block close -s $session $block | complete | ignore
  }
  if $run.exit_code != 0 {
    error make {msg: $"sudo ($argv | first) failed in the Rex pane with exit ($run.exit_code)"}
  }
}

def sudo-wants-rex [] {
  (($env.HEY_REX? | default "1") != "0") and (not (is-terminal --stdin)) and ($env.REX_SESSION? | is-not-empty) and ((which rex) | is-not-empty) and ((^/usr/bin/sudo -n true | complete).exit_code != 0)
}

export def sudo-path [] {
  let path_prefixes = ([
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
  ] | where {|dir| $dir | path exists })
  let path_prefix = ($path_prefixes | str join ":")
  if $path_prefix != "" {
    # Nushell keeps PATH as a list; interpolating it directly yields "[a, b]".
    $"($path_prefix)(char esep)([$env.PATH] | flatten | str join (char esep))"
  } else {
    ""
  }
}

export def maybe-suggest-cache-bootstrap [stderr: string] {
  if ($stderr | str contains "--accept-flake-config") {
    print -e ""
    print -e "Nix is ignoring this flake's binary cache configuration."
    print -e "To trust only the dotfiles-approved caches without enabling accept-flake-config globally, run:"
    print -e ""
    print -e "  hey setup-caches --apply"
    print -e ""
  }
}

export def check-flake-lock [] {
  let ctx = (context)
  let lock = ($ctx.flake_dir | path join "flake.lock")
  let marker = '^<{7}|^={7}|^>{7}'

  let lock_grep = (^grep -nE $marker $lock | complete)
  if $lock_grep.exit_code == 0 {
    print -e "error: flake.lock contains git conflict markers — resolve them first"
    if (($lock_grep.stdout | str trim) | is-not-empty) {
      print -e $lock_grep.stdout
    }
    error make {msg: "flake.lock contains conflict markers"}
  }

  let jq_check = (^jq empty $lock | complete)
  if $jq_check.exit_code != 0 {
    print -e "error: flake.lock is not valid JSON — check for corruption or conflict markers"
    error make {msg: "flake.lock is not valid JSON"}
  }

  let files_grep = (
    ^git -C $ctx.flake_dir grep -nE $marker -- '*.nix' '*.json' '*.jsonc' '*.yml' '*.yaml' '*.toml' | complete
  )
  if $files_grep.exit_code == 0 {
    if (($files_grep.stdout | str trim) | is-not-empty) {
      print $files_grep.stdout
    }
    print -e "error: files above contain git conflict markers — resolve them first"
    error make {msg: "tracked config files contain conflict markers"}
  }
}


export def local-skill-leaks [] {
  let ctx = (context)
  let local_dir = ($ctx.flake_dir | path join ".agents" "skills")
  let global_dir = ($env.HOME | path join ".agents" "skills")

  if not ($local_dir | path exists) {
    return []
  }

  ls $local_dir
  | where type == dir
  | each {|entry|
      let name = ($entry.name | path basename)
      let local_skill = ($entry.name | path join "SKILL.md")
      let global_skill = ($global_dir | path join $name "SKILL.md")
      if (($local_skill | path exists) and ($global_skill | path exists)) {
        $name
      } else {
        null
      }
    }
  | compact
  | sort
}

export def check-local-skill-leaks [] {
  let leaks = (local-skill-leaks)
  if not ($leaks | is-empty) {
    print -e "error: dotfiles project-local skills leaked into ~/.agents/skills:"
    for leak in $leaks {
      print -e $"  - ($leak)"
    }
    print -e ""
    print -e "These skills come from .agents/skills/ and must remain project-local to this repo."
    print -e "Run `hey skills-cleanup-local-leaks`, then retry `hey re`."
    error make {msg: "project-local skills leaked into global skills target"}
  }
}


export def wait-homebrew-idle [ctx: record] {
  if $ctx.os_name != "macos" {
    return
  }

  ^bash ($ctx.flake_dir | path join "bin" "hey.d" ".lib" "wait-homebrew-idle.sh")
}


# Full-system evaluations are memory-heavy and dominated by nix-daemon round
# trips; concurrent ones (many agent sessions) slow each other down 10-20x.
# Serialize them per user with an atomic mkdir lock. The holder's pid and
# process start time identify it, so a crashed or killed holder is detected
# and its lock reclaimed instead of blocking forever.
export def system-eval-lock-path [] {
  let cache = ($env.XDG_CACHE_HOME? | default ($env.HOME | path join ".cache"))
  $cache | path join "hey" "system-eval.lock"
}

# Empty when the process is gone or ps is unavailable (liveness then uses kill -0).
def process-start [pid: int] {
  let result = (try { ^ps -o lstart= -p $"($pid)" | complete } catch { {exit_code: 1} })
  if $result.exit_code == 0 { $result.stdout | str trim } else { "" }
}

# Describe the current lock holder; `stale` is true when it can be reclaimed.
export def system-eval-lock-state [lock: path] {
  let owner = (try { open --raw ($lock | path join "owner.nuon") | from nuon } catch { null })
  if $owner == null {
    # The holder may be between mkdir and writing its owner record.
    let age = (try { (date now) - (ls -D $lock | first | get modified) } catch { 0sec })
    return {stale: ($age > 1min), description: "an unidentified process"}
  }
  let alive = if ($owner.started | is-not-empty) {
    (process-start $owner.pid) == $owner.started
  } else {
    (^kill -0 $"($owner.pid)" | complete).exit_code == 0
  }
  {
    stale: (not $alive)
    description: $"pid ($owner.pid) \(($owner.label)) in ($owner.cwd) since ($owner.acquired)"
  }
}

export def with-system-eval-lock [label: string, body: closure] {
  let lock = (system-eval-lock-path)
  ^mkdir -p ($lock | path dirname)
  mut last_notice = ((date now) - 1day)
  loop {
    if (^mkdir $lock | complete).exit_code == 0 {
      break
    }
    let state = (system-eval-lock-state $lock)
    if $state.stale {
      print -e $"hey: reclaiming stale system-evaluation lock from ($state.description)"
      # Rename first so only one waiter reclaims a given stale lock.
      let stale = $"($lock).stale-($nu.pid)"
      if (^mv $lock $stale | complete).exit_code == 0 {
        ^rm -rf $stale
      }
      continue
    }
    if ((date now) - $last_notice) > 1min {
      print -e $"hey: waiting for the system-evaluation lock held by ($state.description)"
      print -e $"hey: lock path ($lock); Ctrl-C to stop waiting"
      $last_notice = (date now)
    }
    sleep 2sec
  }

  {
    pid: $nu.pid
    started: (process-start $nu.pid)
    label: $label
    cwd: (pwd)
    acquired: (date now | format date "%Y-%m-%dT%H:%M:%S%z")
  } | to nuon | save -f ($lock | path join "owner.nuon")

  let result = (try { do $body } catch {|err| ^rm -rf $lock; $err.raw })
  ^rm -rf $lock
  $result
}

# Pure: turn a `sys mem` record (plus macOS's kern.memorystatus_vm_pressure_level
# and other full-system evaluators) into human-readable warnings.
export def memory-pressure-warnings [mem: record, pressure_level: int, evaluators: list<string>] {
  mut warnings = []
  let swap_total = ($mem | get "swap total")
  let swap_used = ($mem | get "swap used")
  if ($swap_total | into int) > 0 {
    let swap_percent = ((($swap_used | into int) * 100 / ($swap_total | into int)) | math round)
    if $swap_percent >= 85 {
      $warnings = ($warnings | append $"swap is ($swap_percent)% full \(($swap_used) of ($swap_total))")
    }
  }
  let total = ($mem.total | into int)
  if $total > 0 and (($mem.available | into int) / $total) < 0.10 {
    $warnings = ($warnings | append $"only ($mem.available) of ($mem.total) memory is available")
  }
  if $pressure_level >= 4 {
    $warnings = ($warnings | append "macOS reports CRITICAL memory pressure")
  } else if $pressure_level >= 2 {
    $warnings = ($warnings | append "macOS reports memory pressure (warn)")
  }
  let count = ($evaluators | length)
  if $count > 0 {
    $warnings = ($warnings | append $"($count) other full-system evaluation\(s) running:")
    $warnings = ($warnings | append ($evaluators | each {|line| $"  ($line)" }))
  }
  $warnings
}

export def warn-if-memory-pressure [] {
  let mem = (try { sys mem } catch { return })
  let pressure_level = if $nu.os-info.name == "macos" {
    try { ^sysctl -n kern.memorystatus_vm_pressure_level | str trim | into int } catch { 0 }
  } else { 0 }
  let processes = (try { ^ps -axo pid=,command= | complete } catch { {exit_code: 1, stdout: ""} })
  let evaluators = (
    $processes.stdout
    | lines
    | each {|line| $line | str trim }
    | where {|line| $line =~ 'darwinConfigurations|nixosConfigurations|darwin-rebuild|nixos-rebuild' }
    # Ignore shells and tools whose command line merely mentions them.
    | where {|line| not ($line =~ '^\d+ \S*\b(ba|z)?sh -c |^\d+ \S*\b(grep|rg|ps|timeout) ') }
    | where {|line| not ($line starts-with $"($nu.pid) ") }
    | each {|line| $line | str substring 0..160 }
  )
  let warnings = (memory-pressure-warnings $mem $pressure_level $evaluators)
  if ($warnings | is-not-empty) {
    print -e "hey re: warning: this machine is under memory pressure; evaluation may be 10-20x slower:"
    for line in $warnings { print -e $"hey re:   ($line)" }
    print -e "hey re: continuing; stop other Nix evaluations or agent sessions if this drags on."
  }
}

# Upstream `darwin-rebuild switch|check` evaluates the whole config as root,
# with root's cold eval cache. For these actions hey evaluates and builds once
# as the invoking user, then hands upstream darwin-rebuild a tiny flake whose
# only output is that prebuilt system. Root then runs darwin-rebuild's own
# switch/check (profile, activate-user handling, activation) after a trivial
# evaluation, and sudo rules that allow only darwin-rebuild keep working.
# Flags that change the profile or what gets built keep the upstream path.
const DARWIN_PREBUILT_ACTIONS = [switch check build]
const DARWIN_PASSTHROUGH_FLAGS = [
  --flake --no-flake -p --profile-name --rollback -G --switch-generation
  --list-generations --dry-run
]

export def darwin-prebuilt-supported [action: string, args: list<string>] {
  ($action in $DARWIN_PREBUILT_ACTIONS) and ($args | all {|arg| $arg not-in $DARWIN_PASSTHROUGH_FLAGS })
}

# Build the host's system as the invoking user. Returns {drv, out}.
export def darwin-build-system [ctx: record, build_args: list<string>, --out-link: string] {
  let installable = $"($ctx.flake_dir)#darwinConfigurations.($ctx.flake_host).system"
  let link_args = if $out_link == null { ["--no-link"] } else { ["--out-link" $out_link] }
  print -e "building the system configuration..."
  let built = (^nix build --json ...$link_args ...$build_args $installable | from json | first)
  let system = {drv: $built.drvPath, out: $built.outputs.out}
  if not ($system.out | path join "activate" | path exists) {
    error make {msg: $"nix build returned ($system.out), which is not a nix-darwin system"}
  }
  $system
}

export def darwin-prebuilt-flake [dir: path, system: record] {
  mkdir $dir
  $'{
  # Generated by hey: the system ($system.out) was already built.
  outputs = _: {
    darwinConfigurations.hey.system = {
      type = "derivation";
      name = "darwin-system";
      outputName = "out";
      outputs = [ "out" ];
      drvPath = builtins.storePath "($system.drv)";
      outPath = builtins.storePath "($system.out)";
    };
  };
}
' | save -f ($dir | path join "flake.nix")
}

export def darwin-rebuild-prebuilt [
  ctx: record
  action: string
  build_args: list<string>
  root_args: list<string>
] {
  if $action == "build" {
    # Upstream leaves ./result in the caller's directory and needs no root.
    let system = (darwin-build-system $ctx $build_args --out-link ($env.PWD | path join "result"))
    print $system.out
    return
  }

  let work = (^mktemp -d | str trim)
  try {
    # The out-link roots the system against garbage collection until it is
    # the active profile. It sits outside the flake directory, which root's
    # evaluation copies into the store.
    let system = (darwin-build-system $ctx $build_args --out-link ($work | path join "system"))
    let flake = ($work | path join "flake")
    darwin-prebuilt-flake $flake $system
    let resolved = (
      ^nix build --json --no-link --impure --no-write-lock-file $"($flake)#darwinConfigurations.hey.system"
      | from json | first | get outputs.out
    )
    if $resolved != $system.out {
      error make {msg: $"prebuilt flake resolved to ($resolved), expected ($system.out)"}
    }
    let current = ((^bash -c $"[[ -x '($ctx.darwin_rebuild)' ]]" | complete).exit_code == 0)
    let darwin_rebuild = if $current {
      $ctx.darwin_rebuild
    } else {
      $system.out | path join "sw" "bin" "darwin-rebuild"
    }
    with-sudo-path { run-sudo $darwin_rebuild --flake $"($flake)#hey" ...$root_args --impure $action }
  } catch {|err|
    ^rm -rf $work
    $err.raw
  }
  ^rm -rf $work
}

export def system-rebuild [ctx: record, action: string, ...args: string] {
  let agent_mode = (
    (($env.AGENT? | default "") == "1")
    or (($env.PI_CODING_AGENT? | default "") == "true")
    or (($env.CLAUDECODE? | default "") == "1")
  )
  let agent_rebuild_args = if $agent_mode { ["--no-write-lock-file" "--show-trace"] } else { ["--no-write-lock-file"] }
  let existing_nix_config = ($env.NIX_CONFIG? | default "")
  let authenticated_nix_config = if $ctx.os_name == "macos" {
    github-nix-config
  } else {
    $existing_nix_config
  }

  # Pre-fetch every locked input before rebuilding. Darwin uses its gh token;
  # the NUC wrapper reads the root-only opnix token.
  if $agent_mode {
    print $"hey re: archiving flake inputs for ($ctx.flake_host)..."
  }
  let archive_result = if $ctx.os_name == "macos" {
    with-env { NIX_CONFIG: $authenticated_nix_config } {
      ^bash -c $"set -euo pipefail; cd '($ctx.flake_dir)'; nix flake archive --no-update-lock-file >/dev/null" | complete
    }
  } else {
    let private_github = "/run/current-system/sw/bin/nix-private-github"
    if ($private_github | path exists) {
      ^sudo $private_github nix flake archive --no-update-lock-file $ctx.flake_dir | complete
    } else {
      ^bash -c $"set -euo pipefail; cd '($ctx.flake_dir)'; nix flake archive --no-update-lock-file >/dev/null" | complete
    }
  }
  maybe-suggest-cache-bootstrap $archive_result.stderr
  if (($archive_result.stdout | str trim) | is-not-empty) {
    print $archive_result.stdout
  }
  if (($archive_result.stderr | str trim) | is-not-empty) {
    print -e $archive_result.stderr
  }
  let unlocked_input = ($archive_result.stderr | str contains "lock file contains unlocked input")
  if $archive_result.exit_code != 0 {
    if $unlocked_input {
      print -e "hey re: continuing despite unlocked local input during pre-archive"
    } else {
      error make {msg: "nix flake archive failed"}
    }
  }
  if $ctx.os_name == "macos" {
    wait-homebrew-idle $ctx
  }

  with-system-eval-lock $"hey ($action) ($ctx.flake_host)" {
    warn-if-memory-pressure
    if $agent_mode {
      print $"hey re: rebuilding ($ctx.flake_host) ($action)..."
    }

    if $ctx.os_name == "macos" {
      with-env { NIX_CONFIG: $authenticated_nix_config } {
        if (darwin-prebuilt-supported $action $args) {
          darwin-rebuild-prebuilt $ctx $action [...$agent_rebuild_args ...$args] $agent_rebuild_args
        } else {
          let has_darwin_rebuild = ((^bash -c $"[[ -x '($ctx.darwin_rebuild)' ]]" | complete).exit_code == 0)
          let darwin_rebuild = if $has_darwin_rebuild {
            $ctx.darwin_rebuild
          } else {
            print $"darwin-rebuild not found at ($ctx.darwin_rebuild), building via nix..."
            let fallback = ((darwin-build-system $ctx $agent_rebuild_args).out | path join "sw" "bin" "darwin-rebuild")
            if not ($fallback | path exists) {
              print -e "Error: darwin-rebuild not found in build result"
              error make {msg: "darwin-rebuild fallback missing in build result"}
            }
            $fallback
          }
          with-sudo-path { run-sudo $darwin_rebuild --flake $"($ctx.flake_dir)#($ctx.flake_host)" ...$agent_rebuild_args $action ...$args }
        }
      }
    } else {
      let private_github = "/run/current-system/sw/bin/nix-private-github"
      if ($private_github | path exists) {
        with-sudo-path { ^sudo $private_github nixos-rebuild --flake $ctx.flake_dir ...$agent_rebuild_args $action ...$args }
      } else {
        with-sudo-path { ^nixos-rebuild --flake $ctx.flake_dir --sudo ...$agent_rebuild_args $action ...$args }
      }
    }
  }
}

export def post-rebuild [ctx: record] {
  if $ctx.os_name == "macos" {
    return
  }

  ^bash -c "
    set -euo pipefail
    if systemctl list-unit-files hermes-agent.service >/dev/null 2>&1; then
      echo '=== hermes-agent: system-managed restart handled by activation ==='
    else
      echo '=== no Hermes system service present ==='
    fi
  "
}
