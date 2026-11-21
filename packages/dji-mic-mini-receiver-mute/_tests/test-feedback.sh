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
    --argjson feedbackFails "${fixture_feedback_fails:-false}" \
    '{
      receiverMatches: $receiverMatches,
      beforeMuted: $beforeMuted,
      writeMode: $writeMode,
      readbackMode: $readbackMode,
      feedbackFails: $feedbackFails
    }' >"$destination"
}

run_fixture() {
  local name="$1"
  local expected_exit="$2"
  local input="$test_tmp/$name-input.json"
  local output="$test_tmp/$name-output.json"
  shift 2

  make_fixture "$input" "$1" "$2" "$3" "$4"
  shift 4
  set +e
  DJI_RECEIVER_MUTE_FIXTURE_INPUT="$input" \
    DJI_RECEIVER_MUTE_FIXTURE_OUTPUT="$output" \
    "$fixture_binary" "$@" >/dev/null 2>&1
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

run_fixture mute 0 1 false success verified toggle
jq -e '.afterMuted == true and .sounds == ["mic_mute.caf"] and .stderr == []' "$test_tmp/mute-output.json" >/dev/null
jq -e '.events == ["lock", "resolve", "read:false", "write:true", "readback:true:300", "unlock", "sound:mic_mute.caf"]' "$test_tmp/mute-output.json" >/dev/null

run_fixture unmute 0 1 true success verified toggle
jq -e '.afterMuted == false and .sounds == ["mic_unmute.caf"] and .stderr == []' "$test_tmp/unmute-output.json" >/dev/null
jq -e '.events == ["lock", "resolve", "read:true", "write:false", "readback:false:300", "unlock", "sound:mic_unmute.caf"]' "$test_tmp/unmute-output.json" >/dev/null

run_fixture missing 1 0 false success verified toggle
run_fixture ambiguous 1 2 false success verified toggle
run_fixture setter-failure 1 1 false failure verified toggle
run_fixture mismatch 1 1 false success mismatch toggle
run_fixture no-op 1 1 false no-op verified toggle
run_fixture timeout 1 1 false success timeout toggle

for failure in missing ambiguous setter-failure mismatch no-op timeout; do
  jq -e '.sounds == ["Sosumi.aiff"] and .stdout == [] and (.stderr | length) == 1' "$test_tmp/$failure-output.json" >/dev/null
done

# Explicit commands must wait for hardware readback too. A delayed device
# distinguishes a verified change from an immediate, stale read after a write.
for command in mute on unmute off; do
  if [[ "$command" == mute || "$command" == on ]]; then
    before=false
    expected=true
    sound=mic_mute.caf
  else
    before=true
    expected=false
    sound=mic_unmute.caf
  fi
  run_fixture "$command-delayed" 0 1 "$before" delayed verified "$command"
  jq -e --argjson expected "$expected" --arg sound "$sound" \
    '.afterMuted == $expected and .sounds == [$sound] and .stderr == []' \
    "$test_tmp/$command-delayed-output.json" >/dev/null

  run_fixture "$command-no-op" 1 1 "$before" no-op verified "$command"
  jq -e '.sounds == ["Sosumi.aiff"] and .stdout == []' "$test_tmp/$command-no-op-output.json" >/dev/null

  # Repeated mute/unmute requests are idempotent, even if writes would fail.
  run_fixture "$command-already-set" 0 1 "$expected" failure verified "$command"
  jq -e --argjson expected "$expected" \
    '.afterMuted == $expected and .sounds == [] and .stderr == [] and
     (.events | any(startswith("write")) | not)' \
    "$test_tmp/$command-already-set-output.json" >/dev/null
done

run_fixture status 0 1 true failure timeout status
run_fixture default-status 0 1 false failure timeout
for name in status default-status; do
  jq -e '.sounds == [] and .stderr == [] and (.stdout | length) == 1 and
    (.events | any(startswith("write")) | not)' "$test_tmp/$name-output.json" >/dev/null
done
jq -e '.stdout[0] | endswith(" mute=on")' "$test_tmp/status-output.json" >/dev/null
jq -e '.stdout[0] | endswith(" mute=off")' "$test_tmp/default-status-output.json" >/dev/null

run_fixture help 0 0 false failure timeout --help
run_fixture short-help 0 0 false failure timeout -h
run_fixture invalid 1 0 false failure timeout typo
run_fixture extra-argument 1 1 false success verified toggle extra
for name in help short-help invalid extra-argument; do
  jq -e '.events == [] and .sounds == [] and .afterMuted == false' "$test_tmp/$name-output.json" >/dev/null
done
jq -e '.stdout[0] | contains("Usage:")' "$test_tmp/help-output.json" >/dev/null
jq -e '.stderr[0] | contains("Usage:")' "$test_tmp/invalid-output.json" >/dev/null

# A failed sound must not turn a verified toggle into an apparent failure.
fixture_feedback_fails=true run_fixture feedback-failure 0 1 false success verified toggle
jq -e '.afterMuted == true and (.stdout[0] | endswith(" mute=on")) and
  (.stderr[0] | contains("mute change verified, but feedback failed"))' \
  "$test_tmp/feedback-failure-output.json" >/dev/null

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
