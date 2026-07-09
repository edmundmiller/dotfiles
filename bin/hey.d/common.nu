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
  let file_pwd = ($env.FILE_PWD? | default (pwd) | path expand)
  let cwd = (pwd | path expand)
  let flake_dir = (
    [
      ($env.FLAKE_DIR? | default null)
      (find-flake-up $cwd)
      ($env.HOME | path join ".config" "dotfiles")
      (find-flake-up $file_pwd)
      ($env.DOTFILES? | default null)
      (if (($env.DOTFILES_BIN? | default "") | is-empty) { null } else { $env.DOTFILES_BIN | path dirname })
    ]
    | compact
    | each {|dir| $dir | path expand}
    | where {|dir| (($dir | path join "flake.nix") | path exists)}
    | first
    | default (find-flake-up $file_pwd)
    | default (find-flake-up $cwd)
    | default ($file_pwd | path join ".." | path expand)
  )

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

export def with-sudo-path [body: closure] {
  let path = (sudo-path)
  if $path != "" {
    with-env { PATH: $path } { do $body }
  } else {
    do $body
  }
}

export def sudo-path [] {
  let path_prefixes = ([
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
  ] | where {|dir| $dir | path exists })
  let path_prefix = ($path_prefixes | str join ":")
  if $path_prefix != "" {
    $"($path_prefix):($env.PATH)"
  } else {
    ""
  }
}

export def run-in-flake [cmd: string] {
  let ctx = (context)
  ^bash -c $"set -euo pipefail; cd '($ctx.flake_dir)'; ($cmd)"
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


export def wait-homebrew-idle [] {
  if not (is-darwin) {
    return
  }

  let ctx = (context)
  ^bash ($ctx.flake_dir | path join "bin" "hey.d" "wait-homebrew-idle.sh")
}


export def moshi-client-active [] {
  (($env.MOSHI_CLIENT? | default "") | str downcase) in ["1" "true" "yes"]
}

export def fail-if-moshi-client-rebuild [ctx: record, action: string] {
  let activates_darwin_apps = ($ctx.os_name == "macos") and ($action in ["switch" "test"])

  if $activates_darwin_apps and (moshi-client-active) {
    print -e $"BLOCKED: hey ($action) did not activate"
    print -e "CONSEQUENCE: Nix-managed symlinks/runtime configs are unchanged; affected files still point to the old store path."
    print -e "CAUSE: MOSHI_CLIENT=1; darwin-rebuild is running under launchctl managername=Background and cannot update /Applications/Nix Apps."
    print -e "AGENT_ACTION: stop; do not retry here; do not change Nix config to bypass this guard."
    print -e "HUMAN_FIX: open Ghostty/Finder-launched terminal (Aqua session), then rerun the same `hey ...` command."
    print -e "VERIFY: after success, re-read the affected Nix-managed file/service (for example `readlink ~/.omp/agent/config.yml`)."
    error make {msg: $"BLOCKED hey ($action): Moshi/mosh session cannot activate macOS apps; no activation happened"}
  }
}

export def system-rebuild [action: string, ...args: string] {
  let ctx = (context)
  let agent_mode = (
    (($env.AGENT? | default "") == "1")
    or (($env.PI_CODING_AGENT? | default "") == "true")
    or (($env.CLAUDECODE? | default "") == "1")
  )
  let agent_rebuild_args = if $agent_mode { ["--no-write-lock-file" "--show-trace"] } else { ["--no-write-lock-file"] }
  let agent_nix_args = if $agent_mode { ["--quiet" "--show-trace"] } else { [] }

  # Pre-fetch flake inputs as the user before sudo. sudo strips access to
  # the 1Password SSH agent socket (it lives under the user's home), so
  # private inputs like agents-workspace fail to fetch from root. Archiving
  # here puts every locked input into /nix/store using the user's SSH agent,
  # after which the root-side eval doesn't need network.
  if $agent_mode {
    print $"hey re: archiving flake inputs for ($ctx.flake_host)..."
  }
  let archive_result = (^bash -c $"set -euo pipefail; cd '($ctx.flake_dir)'; nix flake archive --no-update-lock-file >/dev/null" | complete)
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
    wait-homebrew-idle
  }

  if $agent_mode {
    print $"hey re: rebuilding ($ctx.flake_host) ($action)..."
  }

  if $ctx.os_name == "macos" {
    let has_darwin_rebuild = ((^bash -c $"[[ -x '($ctx.darwin_rebuild)' ]]" | complete).exit_code == 0)

    if $has_darwin_rebuild {
      with-sudo-path { ^/usr/bin/sudo $ctx.darwin_rebuild --flake $"($ctx.flake_dir)#($ctx.flake_host)" ...$agent_rebuild_args $action ...$args }
    } else {
      print $"darwin-rebuild not found at ($ctx.darwin_rebuild), building via nix..."
      ^bash -c $"set -euo pipefail; cd '($ctx.flake_dir)'; nix build '.#darwinConfigurations.($ctx.flake_host).system' ($agent_nix_args | str join ' ')"

      let fallback = ($ctx.flake_dir | path join "result" "sw" "bin" "darwin-rebuild")
      if not ($fallback | path exists) {
        print -e "Error: darwin-rebuild not found in build result"
        error make {msg: "darwin-rebuild fallback missing in ./result"}
      }

      let old_pwd = (pwd)
      cd $ctx.flake_dir
      with-sudo-path { ^/usr/bin/sudo ./result/sw/bin/darwin-rebuild --flake $".#($ctx.flake_host)" ...$agent_rebuild_args $action ...$args }
      cd $old_pwd
    }
  } else {
    with-sudo-path { ^nixos-rebuild --flake $ctx.flake_dir --sudo ...$agent_rebuild_args $action ...$args }
  }
}

export def post-rebuild [] {
  if (is-darwin) {
    ^bash -c '
      set -euo pipefail
      pi_bin="$(command -v pi || true)"
      if [ -z "$pi_bin" ] && [ -x "/etc/profiles/per-user/$USER/bin/pi" ]; then
        pi_bin="/etc/profiles/per-user/$USER/bin/pi"
      fi

      if [ -z "$pi_bin" ]; then
        echo "warning: pi not found; skipping pi package update" >&2
        exit 0
      fi

      # node-gyp 8 (pulled by some Pi extensions) still imports distutils.
      # Homebrew python on macOS 27 is 3.14 and no longer ships it, while
      # Apple /usr/bin/python3 is 3.9 and still works for these native rebuilds.
      if [ -x /usr/bin/python3 ]; then
        export PYTHON=/usr/bin/python3
      fi

      echo "=== pi: update extensions ==="
      if ! "$pi_bin" update --extensions; then
        echo "warning: pi package update failed; rebuild already completed" >&2
      fi

      # Pi 0.79.x can prune scoped packages from the mutable npm project during
      # update. Reinstall this one after updates because config depends on its
      # flat permission schema.
      if grep -q "npm:@gotgenes/pi-permission-system" "$HOME/.pi/agent/settings.json" 2>/dev/null \
        && [ ! -f "$HOME/.pi/agent/npm/node_modules/@gotgenes/pi-permission-system/src/index.ts" ]; then
        echo "=== pi: reconcile @gotgenes/pi-permission-system ==="
        PYTHON="''${PYTHON:-/usr/bin/python3}" npm install @gotgenes/pi-permission-system@latest \
          --prefix "$HOME/.pi/agent/npm" --legacy-peer-deps \
          || echo "warning: failed to install @gotgenes/pi-permission-system" >&2
      fi
    '
    return
  }

  ^bash -c "
    set -euo pipefail
    if systemctl list-unit-files hermes-agent.service >/dev/null 2>&1; then
      echo '=== hermes-agent: system-managed restart handled by activation ==='
    elif grep -q 'openclaw-gateway' /proc/self/cgroup 2>/dev/null; then
      echo '=== openclaw-gateway: skipping restart (deploy triggered by openclaw) ==='
    elif systemctl --user list-unit-files openclaw-gateway.service >/dev/null 2>&1; then
      echo '=== try-restart openclaw-gateway ==='
      systemctl --user try-restart openclaw-gateway.service
    else
      echo '=== no legacy openclaw-gateway user unit present ==='
    fi
  "
}
