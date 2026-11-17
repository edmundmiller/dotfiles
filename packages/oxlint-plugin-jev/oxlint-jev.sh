#!@runtimeShell@
set -eu
export PATH="@nodejsBin@:$PATH"
if [ -z "${TYPESAFE_API_KEY:-}" ] && [ -n "${TYPESAFE_API_KEY_FILE:-}" ]; then
  TYPESAFE_API_KEY="$(tr -d '\n' < "$TYPESAFE_API_KEY_FILE")"
  export TYPESAFE_API_KEY
fi
config="@jevConfig@"
if [ "${1:-}" = --presets ]; then
  config="@presetsConfig@"
  shift
fi
exec node "@lintChanged@" --oxlint="@oxlintBin@" \
  --threads=1 \
  --disable-nested-config \
  --config "$config" \
  @ignoreArgs@ \
  "$@"
