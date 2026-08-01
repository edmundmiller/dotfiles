#!/usr/bin/env bash
# Recording, hermetic `herdr` shim for skill evals.
#
# Two jobs:
#   1. Observe. Every argv is appended to $HERDR_SHIM_LOG, so helpInvocations
#      is measured from actual calls instead of trusted from a self-reported
#      JSON field the model can get wrong or inflate.
#   2. Enforce. The prompt says "do not mutate the live session", but nothing
#      made that true -- the eval runs against the user's real herdr session.
#
# This shim NEVER executes the real herdr. Help text is replayed from a
# captured corpus ($HERDR_HELP_CORPUS), so there is no code path from the eval
# to the live IPC socket. The shim is the recording and usability half of the
# pair; the enforcing half is an OS sandbox that denies the herdr IPC socket
# directory. Socket denial, not binary denial: blocking the executable is
# defeated by copying it elsewhere, whereas without the socket every route to
# the live session fails no matter which binary runs.
# Fail closed: if the audit log cannot be written, refuse the call rather
# than silently letting an unrecorded, unenforced command through.
set -euo pipefail

if ! printf '%s\n' "$*" >>"${HERDR_SHIM_LOG:?HERDR_SHIM_LOG must be set}"; then
  echo "herdr-shim: cannot write audit log; refusing to run herdr $*" >&2
  exit 65
fi

is_help=0
for arg in "$@"; do
  case "$arg" in
    --help | -h | --version | -V) is_help=1 ;;
  esac
done
case "${1:-}" in
  # `help` is an unknown command in 0.7.5 and is replayed as such. Bare `herdr`
  # is NOT help -- it launches or attaches a session, so it is refused like any
  # other live command; treating it as help would hand the arm a discovery
  # route the prompt never granted.
  help) is_help=1 ;;
esac

if [[ $is_help -eq 0 ]]; then
  # Help only. The prompt grants `herdr ... --help` and nothing else, so live
  # queries stay refused: `pane list` would hand a response-shape case the
  # root_pane/pane answer it is supposed to already know, and it would leak the
  # user's real session contents into the transcript.
  echo "herdr-shim: refused non-help command in eval sandbox: herdr $*" >&2
  exit 64
fi

exec /usr/bin/python3 - "${HERDR_HELP_CORPUS:?HERDR_HELP_CORPUS must be set}" "$@" <<'PY'
import json, sys

corpus = json.load(open(sys.argv[1]))
argv = sys.argv[2:]

# Normalise: corpus keys are the subcommand path plus a single --help.
path = [a for a in argv if not a.startswith("-")]
flags = [a for a in argv if a.startswith("-")]

if "--version" in flags or "-V" in flags:
    key = "--version"
elif path and path[0] == "help":
    # 0.7.5 has no `help <path>` form -- `herdr help agent prompt` returns
    # "unknown command: help" (exit 2), same as bare `help`. Collapsing every
    # help-prefixed call to that one captured entry reproduces the real CLI;
    # resolving it to `agent prompt --help` would invent a surface that does
    # not exist and teach the help-only arm a command shape that fails.
    key = "help"
elif path:
    key = " ".join(path) + " --help"
else:
    key = "--help"

entry = corpus.get(key)
if entry is None:
    # Exact matches only. The real CLI does fall back for unknown subcommands,
    # but with different text than the parent's --help, and some misses reach
    # the socket -- so replaying an approximation would feed the arm output the
    # real CLI never produces and could launder a hallucinated subcommand into
    # something that looks supported. Fail visibly instead.
    sys.stderr.write(
        "herdr-shim: no captured help for 'herdr %s'; "
        "regenerate herdr-help-corpus.json if this is a real command\n" % key
    )
    sys.exit(66)

sys.stdout.write(entry["stdout"])
sys.exit(entry["exit"])
PY
