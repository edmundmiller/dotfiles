#!/bin/sh
# Report agent state to Rex as an OSC 7501 program status (no-op outside Rex).
# Usage: agent-status.sh AGENT STATE [MESSAGE]
# Hooks run without a controlling terminal, so find the pane's tty by walking
# up the process tree.
[ -n "$REX_BLOCK" ] || exit 0
agent=$1 state=$2 msg=${3:-}
pid=$$
tty=
while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; do
  t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  case $t in
    '' | '?' | '??') ;;
    *) tty=/dev/$t; break ;;
  esac
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
[ -w "$tty" ] || exit 0
extra=
case $state in
  blocked) extra=":kind=permission" ;;
esac
if [ -n "$msg" ]; then
  extra="$extra:msg=$(printf '%s' "$msg" | base64 | tr -d '\n')"
fi
printf '\033]7501;state=%s:app=%s%s\033\\' "$state" "$agent" "$extra" >"$tty" 2>/dev/null
exit 0
