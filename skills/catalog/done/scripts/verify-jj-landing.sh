#!/usr/bin/env bash
set -euo pipefail

task_revision=${1:?usage: verify-jj-landing.sh TASK_REVISION DEFAULT_BOOKMARK REMOTE}
default_bookmark=${2:?usage: verify-jj-landing.sh TASK_REVISION DEFAULT_BOOKMARK REMOTE}
remote=${3:?usage: verify-jj-landing.sh TASK_REVISION DEFAULT_BOOKMARK REMOTE}

jj root --ignore-working-copy >/dev/null

conflicts=$(jj log --ignore-working-copy -r "${task_revision} & conflicts()" --no-graph -T 'commit_id ++ "\n"')
if [[ -n ${conflicts} ]]; then
  echo "task revision has conflicts: ${task_revision}" >&2
  exit 1
fi

not_landed=$(jj log --ignore-working-copy -r "${task_revision} & ~::${default_bookmark}" --no-graph -T 'commit_id ++ "\n"')
if [[ -n ${not_landed} ]]; then
  echo "task revision is not contained by ${default_bookmark}: ${task_revision}" >&2
  exit 1
fi

local_tip=$(jj log --ignore-working-copy -r "${default_bookmark}" --no-graph -T 'commit_id ++ "\n"')
tracked_tip=$(jj log --ignore-working-copy -r "${default_bookmark}@${remote}" --no-graph -T 'commit_id ++ "\n"')
remote_url=$(jj git remote list | awk -v name="${remote}" '$1 == name { print $2; exit }')
if [[ -z ${remote_url} ]]; then
  echo "jj remote not found: ${remote}" >&2
  exit 1
fi
remote_tip=$(git ls-remote "${remote_url}" "refs/heads/${default_bookmark}" | awk 'NR == 1 { print $1 }')

if [[ -z ${local_tip} || -z ${tracked_tip} || -z ${remote_tip} ]]; then
  echo "missing local, tracked, or authoritative remote bookmark tip" >&2
  exit 1
fi
if [[ ${local_tip} != "${tracked_tip}" ]]; then
  echo "bookmark mismatch local=${local_tip} tracked=${tracked_tip}" >&2
  exit 1
fi
if [[ ${local_tip} != "${remote_tip}" ]]; then
  echo "bookmark mismatch local=${local_tip} tracked=${tracked_tip} remote=${remote_tip}" >&2
  exit 1
fi

printf 'PASS jj landing task=%s bookmark=%s tip=%s remote=%s\n' \
  "${task_revision}" "${default_bookmark}" "${local_tip}" "${remote}"
