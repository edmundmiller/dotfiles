{ pkgs }:
let
  fakeTailscale = pkgs.writeShellApplication {
    name = "tailscale";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      case "$*" in
        "version --json")
          printf '{"version":"test"}\n'
          ;;
        "status --json")
          printf '{"BackendState":"Running","Padding":"'
          head -c 9000 /dev/zero | tr '\0' x
          printf '"}\n'
          ;;
        "serve status --json")
          printf '{}\n'
          ;;
        "ping --c 1 --until-direct=false --timeout=5s test-host")
          printf 'pong from test-host (100.64.0.1) via 192.0.2.1:41641 in 2ms\n'
          ;;
        *)
          echo "fake tailscale received an unexpected command: $*" >&2
          exit 42
          ;;
      esac
    '';
  };
  restrictedTailscaleCli = import ../hermes-tailscale-cli.nix {
    inherit pkgs;
    tailscale = fakeTailscale;
  };
in
pkgs.runCommand "hermes-tailscale-cli-regressions"
  {
    nativeBuildInputs = [
      restrictedTailscaleCli
      pkgs.coreutils
      pkgs.jq
    ];
  }
  ''
    export HERMES_HOME="$TMPDIR/hermes"

    expect_denied() {
      set +e
      denied_output=$(tailscale "$@" 2>&1)
      denied_code=$?
      set -e
      if [ "$denied_code" -ne 64 ] || [ "$denied_output" != "hermes-tailscale: denied command" ]; then
        echo "Restricted Tailscale CLI did not reject: $*" >&2
        exit 1
      fi
    }

    expect_denied serve reset
    expect_denied serve --bg --yes 9121
    expect_denied set --exit-node=test-host
    expect_denied switch another-account
    expect_denied switch --list --json
    expect_denied file cp /tmp/example test-host:
    expect_denied ping --c 2 --until-direct=false --timeout=5s test-host

    test "$(tailscale version --json | jq -r .version)" = test
    test "$(tailscale status --json | jq -r .BackendState)" = Running
    test "$(tailscale serve status --json | jq -r 'type')" = object
    tailscale ping --c 1 --until-direct=false --timeout=5s test-host | grep -Fq 'pong from test-host'

    metadata=$(tailscale hermes-json snapshot status)
    token=$(printf '%s' "$metadata" | jq -er .token)
    bytes=$(printf '%s' "$metadata" | jq -er .bytes)
    test "$bytes" -gt 9000
    test "$(stat -c %a "$HERMES_HOME/cache/hermes-tailscale/$token.json")" = 600

    reconstructed="$TMPDIR/status.json"
    : > "$reconstructed"
    offset=0
    while [ "$offset" -lt "$bytes" ]; do
      tailscale hermes-json chunk "$token" "$offset" | base64 -d >> "$reconstructed"
      offset=$((offset + 2048))
    done
    test "$(stat -c %s "$reconstructed")" -eq "$bytes"
    test "$(jq -r .BackendState "$reconstructed")" = Running
    test "$(jq -r '.Padding | length' "$reconstructed")" -eq 9000

    tailscale hermes-json delete "$token"
    if tailscale hermes-json chunk "$token" 0 >/dev/null 2>&1; then
      echo "Deleted Tailscale snapshot remained readable." >&2
      exit 1
    fi

    metadata=$(tailscale hermes-json snapshot serve)
    token=$(printf '%s' "$metadata" | jq -er .token)
    test "$(tailscale hermes-json chunk "$token" 0 | base64 -d | jq -r 'type')" = object
    tailscale hermes-json delete "$token"

    touch "$out"
  ''
