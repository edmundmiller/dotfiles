{
  pkgs,
  tailscale ? pkgs.tailscale,
}:
let
  implementation = pkgs.writeShellApplication {
    name = "tailscale";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      jq
    ];
    text = ''
      readonly real_tailscale=${tailscale}/bin/tailscale
      readonly chunk_bytes=2048
      readonly max_snapshot_bytes=$((2 * 1024 * 1024))

      deny() {
        echo "hermes-tailscale: denied command" >&2
        exit 64
      }

      cache_dir() {
        if [[ -z "''${HERMES_HOME:-}" || "''${HERMES_HOME:0:1}" != / ]]; then
          echo "hermes-tailscale: HERMES_HOME must be an absolute path" >&2
          exit 70
        fi

        printf '%s/cache/hermes-tailscale\n' "$HERMES_HOME"
      }

      prune_snapshots() {
        local root=$1
        find "$root" -maxdepth 1 -type f \( -name '*.json' -o -name '.snapshot.*' \) -mmin +5 -delete
      }

      snapshot() {
        local source=$1
        local root token temporary destination bytes
        root=$(cache_dir)
        install -d -m 0700 "$root"
        prune_snapshots "$root"

        token=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
        temporary=$(mktemp "$root/.snapshot.XXXXXXXX")
        destination="$root/$token.json"
        trap 'rm -f "$temporary"' EXIT

        case "$source" in
          status)
            "$real_tailscale" status --json | jq -c . > "$temporary"
            ;;
          serve)
            "$real_tailscale" serve status --json | jq -c . > "$temporary"
            ;;
          *)
            deny
            ;;
        esac

        bytes=$(stat -c %s "$temporary")
        if ((bytes == 0 || bytes > max_snapshot_bytes)); then
          echo "hermes-tailscale: invalid snapshot size" >&2
          exit 65
        fi

        chmod 0600 "$temporary"
        mv "$temporary" "$destination"
        trap - EXIT
        printf '{"token":"%s","bytes":%s}\n' "$token" "$bytes"
      }

      chunk() {
        local token=$1
        local offset=$2
        local root source bytes
        [[ "$token" =~ ^[0-9a-f]{32}$ ]] || deny
        [[ "$offset" =~ ^(0|[1-9][0-9]*)$ ]] || deny

        root=$(cache_dir)
        source="$root/$token.json"
        [[ -f "$source" ]] || {
          echo "hermes-tailscale: snapshot not found" >&2
          exit 66
        }

        bytes=$(stat -c %s "$source")
        ((offset < bytes)) || {
          echo "hermes-tailscale: chunk offset is outside the snapshot" >&2
          exit 66
        }

        dd if="$source" iflag=skip_bytes,count_bytes skip="$offset" count="$chunk_bytes" status=none \
          | base64 -w0
        printf '\n'
      }

      delete_snapshot() {
        local token=$1
        local root
        [[ "$token" =~ ^[0-9a-f]{32}$ ]] || deny
        root=$(cache_dir)
        rm -f "$root/$token.json"
      }

      case "''${1:-}" in
        version)
          [[ $# -eq 2 && $2 == --json ]] || deny
          exec "$real_tailscale" version --json
          ;;
        status)
          [[ $# -eq 2 && $2 == --json ]] || deny
          exec "$real_tailscale" status --json
          ;;
        serve)
          [[ $# -eq 3 && $2 == status && $3 == --json ]] || deny
          exec "$real_tailscale" serve status --json
          ;;
        ping)
          [[
            $# -eq 6
              && $2 == --c
              && $3 == 1
              && $4 == --until-direct=false
              && $5 == --timeout=5s
              && $6 =~ ^[A-Za-z0-9][A-Za-z0-9._:-]{0,252}$
          ]] || deny
          exec "$real_tailscale" ping --c 1 --until-direct=false --timeout=5s "$6"
          ;;
        hermes-json)
          case "''${2:-}" in
            snapshot)
              [[ $# -eq 3 ]] || deny
              snapshot "$3"
              ;;
            chunk)
              [[ $# -eq 4 ]] || deny
              chunk "$3" "$4"
              ;;
            delete)
              [[ $# -eq 3 ]] || deny
              delete_snapshot "$3"
              ;;
            *)
              deny
              ;;
          esac
          ;;
        *)
          deny
          ;;
      esac
    '';
  };
in
pkgs.runCommand "hermes-tailscale-cli"
  {
    meta.mainProgram = "tailscale";
  }
  ''
    mkdir -p "$out/bin"
    ln -s ${implementation}/bin/tailscale "$out/bin/tailscale"
  ''
