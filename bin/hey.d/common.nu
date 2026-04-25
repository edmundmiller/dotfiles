export const DARWIN_REBUILD = "/run/current-system/sw/bin/darwin-rebuild"

export def context [] {
  let flake_dir = ($env.FILE_PWD | path join ".." ".." | path expand)
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

export def run-in-flake [cmd: string] {
  let ctx = (context)
  ^bash -lc $"set -euo pipefail; cd '($ctx.flake_dir)'; ($cmd)"
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

export def system-rebuild [action: string, ...args: string] {
  let ctx = (context)

  if $ctx.os_name == "macos" {
    let has_darwin_rebuild = ((^bash -lc $"[[ -x '($ctx.darwin_rebuild)' ]]" | complete).exit_code == 0)

    if $has_darwin_rebuild {
      ^sudo $ctx.darwin_rebuild --flake $"($ctx.flake_dir)#($ctx.flake_host)" $action ...$args
    } else {
      print $"darwin-rebuild not found at ($ctx.darwin_rebuild), building via nix..."
      ^bash -lc $"set -euo pipefail; cd '($ctx.flake_dir)'; nix build '.#darwinConfigurations.($ctx.flake_host).system'"

      let fallback = ($ctx.flake_dir | path join "result" "sw" "bin" "darwin-rebuild")
      if not ($fallback | path exists) {
        print -e "Error: darwin-rebuild not found in build result"
        error make {msg: "darwin-rebuild fallback missing in ./result"}
      }

      let old_pwd = (pwd)
      cd $ctx.flake_dir
      ^sudo ./result/sw/bin/darwin-rebuild --flake $".#($ctx.flake_host)" $action ...$args
      cd $old_pwd
    }
  } else {
    ^nixos-rebuild --flake $ctx.flake_dir --sudo $action ...$args
  }
}

export def post-rebuild [] {
  if (is-darwin) {
    return
  }

  ^bash -lc "
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
