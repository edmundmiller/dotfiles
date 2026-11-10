#!/usr/bin/env bash
set +e

report_dir=$1
release_command=$2
result="$report_dir/result.tsv"
state="$report_dir/state.tsv"
outcome=interrupted
status=1
detail="service ended without a validation result (${SERVICE_RESULT:-unknown}/${EXIT_CODE:-unknown}/${EXIT_STATUS:-unknown})"

if [ -f "$result" ]; then
  IFS=$'\t' read -r outcome status detail < <(tail -n 1 "$result")
elif [ "${SERVICE_RESULT:-}" = "success" ]; then
  outcome=setup
  detail="validation exited without recording a result"
fi

bash -c "$release_command"
cleanup_status=$?
if [ "$cleanup_status" -ne 0 ]; then
  if [ "$outcome" = success ]; then
    outcome=cleanup
    detail="snapshot release or pruning failed"
  else
    outcome="${outcome}+cleanup"
    detail="$detail; snapshot release or pruning failed"
  fi
  status=1
fi

if [ "${SERVICE_RESULT:-success}" != success ] && [ "$status" -eq 0 ]; then
  outcome=interrupted
  status=1
  detail="service ended with ${SERVICE_RESULT:-unknown}/${EXIT_CODE:-unknown}/${EXIT_STATUS:-unknown}"
fi

terminal_state=failed
if [ "$status" -eq 0 ]; then
  terminal_state=completed
fi
printf '%s\t%s\t%s\t%s\t%s\n' \
  "$terminal_state" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$outcome" "$detail" >> "$state"
exit "$status"
