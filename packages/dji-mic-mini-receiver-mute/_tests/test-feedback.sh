#!/usr/bin/env bash
set -euo pipefail

source_root="${1:?usage: test-feedback.sh SOURCE_ROOT}"
test_root="$source_root/_tests"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/dji-mic-feedback.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT

compile_log="$test_tmp/compile.log"
fixture_binary="$test_tmp/dji-mic-mini-receiver-mute-fixture"

if /usr/bin/xcrun swiftc \
  -D DJI_RECEIVER_MUTE_FIXTURE \
  "$source_root/receiver-mute.swift" \
  "$test_root/receiver-mute-fixture.swift" \
  -o "$fixture_binary" \
  2>"$compile_log"; then
  compiled=true
else
  compiled=false
fi

if [[ -f "$test_root/feedback.xfail" ]]; then
  if [[ "$compiled" == true ]]; then
    echo "unexpected pass: verified-feedback fixture now compiles" >&2
    exit 1
  fi
  if ! grep -Eq "statements are not allowed at the top level|cannot find type 'ReceiverAudio'|cannot find type 'ReceiverDeviceID'|cannot find 'runReceiverMuteCLI'" "$compile_log"; then
    echo "fixture compile failed for an unexpected reason" >&2
    sed -n '1,120p' "$compile_log" >&2
    exit 1
  fi
  echo "expected failure: adopted helper has no verified-feedback seam"
  exit 0
fi

if [[ "$compiled" != true ]]; then
  sed -n '1,160p' "$compile_log" >&2
  exit 1
fi

make_fixture() {
  local destination="$1"
  local matches="$2"
  local before="$3"
  local write_mode="$4"
  local readback_mode="$5"

  jq -n \
    --argjson receiverMatches "$matches" \
    --argjson beforeMuted "$before" \
    --arg writeMode "$write_mode" \
    --arg readbackMode "$readback_mode" \
    '{
      receiverMatches: $receiverMatches,
      beforeMuted: $beforeMuted,
      writeMode: $writeMode,
      readbackMode: $readbackMode
    }' >"$destination"
}

run_fixture() {
  local name="$1"
  local expected_exit="$2"
  local input="$test_tmp/$name-input.json"
  local output="$test_tmp/$name-output.json"
  shift 2

  make_fixture "$input" "$@"
  set +e
  DJI_RECEIVER_MUTE_FIXTURE_INPUT="$input" \
    DJI_RECEIVER_MUTE_FIXTURE_OUTPUT="$output" \
    "$fixture_binary" toggle >/dev/null 2>&1
  local actual_exit=$?
  set -e

  if [[ "$actual_exit" -ne "$expected_exit" ]]; then
    echo "$name: expected exit $expected_exit, got $actual_exit" >&2
    exit 1
  fi
  jq -e --argjson exitCode "$expected_exit" '.exitCode == $exitCode' "$output" >/dev/null
  if jq -e '.events[] | select(test("output|default"; "i"))' "$output" >/dev/null; then
    echo "$name: helper crossed the output/default-device boundary" >&2
    exit 1
  fi
}

run_fixture mute 0 1 false success verified
jq -e '.afterMuted == true and .sounds == ["Basso.aiff"]' "$test_tmp/mute-output.json" >/dev/null
jq -e '.events == ["lock", "resolve", "read:false", "write:true", "readback:true:300", "unlock", "sound:Basso.aiff"]' "$test_tmp/mute-output.json" >/dev/null

run_fixture unmute 0 1 true success verified
jq -e '.afterMuted == false and .sounds == ["Tink.aiff"]' "$test_tmp/unmute-output.json" >/dev/null
jq -e '.events == ["lock", "resolve", "read:true", "write:false", "readback:false:300", "unlock", "sound:Tink.aiff"]' "$test_tmp/unmute-output.json" >/dev/null

run_fixture missing 1 0 false success verified
run_fixture ambiguous 1 2 false success verified
run_fixture setter-failure 1 1 false failure verified
run_fixture mismatch 1 1 false success mismatch
run_fixture no-op 1 1 false no-op verified
run_fixture timeout 1 1 false success timeout

for failure in missing ambiguous setter-failure mismatch no-op timeout; do
  jq -e '.sounds == []' "$test_tmp/$failure-output.json" >/dev/null
done

if grep -F 'kAudioObjectPropertyScopeOutput' "$source_root/receiver-mute.swift" >/dev/null; then
  echo "production helper references CoreAudio output scope" >&2
  exit 1
fi
if grep -E 'kAudioHardwarePropertyDefault(Input|Output)Device' "$source_root/receiver-mute.swift" >/dev/null; then
  echo "production helper references a default audio device" >&2
  exit 1
fi
if grep -E 'AirPods|IOBluetooth|CoreBluetooth' "$source_root/receiver-mute.swift" >/dev/null; then
  echo "production helper references AirPods or Bluetooth state" >&2
  exit 1
fi

echo "DJI Mic Mini verified-feedback CLI regressions passed."
