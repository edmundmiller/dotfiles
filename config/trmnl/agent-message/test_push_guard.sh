#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
wrapper="$project_dir/bin/trmnlp"

# Keep the guard test independent of the local Ruby toolchain. With this
# minimal path, an unguarded push reaches the wrapper's normal "not installed"
# path without finding the system Ruby/Bundler shims.
test_bin="$(mktemp -d)"
trap 'rm -rf "$test_bin"' EXIT
test_bash_path="$(command -v bash)" || {
  printf 'missing test dependency: bash\n' >&2
  exit 1
}
test -x "$test_bash_path" || {
  printf 'test dependency is not executable: %s\n' "$test_bash_path" >&2
  exit 1
}
for utility in dirname grep bash; do
  utility_path="$(command -v "$utility")" || {
    printf 'missing test dependency: %s\n' "$utility" >&2
    exit 1
  }
  test -x "$utility_path" || {
    printf 'test dependency is not executable: %s\n' "$utility_path" >&2
    exit 1
  }
  ln -s "$utility_path" "$test_bin/$utility"
done
test_path="$test_bin"
expected_message='refusing trmnlp push: replace id: __UNASSIGNED__ only after verifying the target private plugin'

assert_push_is_guarded() {
  local label="$1"
  shift
  local output
  local status

  set +e
  output="$(PATH="$test_path" "$test_bash_path" "$wrapper" "$@" 2>&1)"
  status=$?
  set -e

  test "$status" -eq 2 || {
    printf '%s: expected exit 2, got %s\n%s\n' "$label" "$status" "$output" >&2
    return 1
  }
  test "$output" = "$expected_message" || {
    printf '%s: unexpected output:\n%s\n' "$label" "$output" >&2
    return 1
  }
}

assert_not_push() {
  local output
  local status

  set +e
  output="$(PATH="$test_path" "$test_bash_path" "$wrapper" --quiet lint 2>&1)"
  status=$?
  set -e

  test "$status" -eq 1 || {
    printf 'non-push command: expected normal missing-tool exit 1, got %s\n%s\n' "$status" "$output" >&2
    return 1
  }
  test "$output" = 'trmnlp is not installed; run bundle install in this project' || {
    printf 'non-push command: unexpected output:\n%s\n' "$output" >&2
    return 1
  }
}

assert_push_is_guarded plain push
assert_push_is_guarded dir_flag --dir . push
assert_push_is_guarded quiet_flag --quiet push
assert_push_is_guarded no_quiet_flag --no-quiet push
assert_push_is_guarded skip_quiet_flag --skip-quiet push
assert_push_is_guarded short_global_flags -d . -q push
assert_push_is_guarded command_options push --force
assert_not_push

printf '%s\n' 'TRMNLP push guard checks passed'
