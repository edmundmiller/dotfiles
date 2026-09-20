#!@runtimeShell@
set -eu
export PATH="@nodejsBin@:$PATH"
if [ -z "${TYPESAFE_API_KEY:-}" ] && [ -n "${TYPESAFE_API_KEY_FILE:-}" ]; then
  TYPESAFE_API_KEY="$(tr -d '\n' < "$TYPESAFE_API_KEY_FILE")"
  export TYPESAFE_API_KEY
fi
exec "@oxlintBin@" \
  --threads=1 \
  --disable-nested-config \
  --config "@jevConfig@" \
  "$@"
