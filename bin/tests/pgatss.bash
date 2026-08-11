#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT

mkdir -p \
  "${test_root}/bin" \
  "${test_root}/home/.config/pgatss" \
  "${test_root}/vault/.agents/skills/pgatss-simulator-booking/scripts"
auth_env="${test_root}/home/.config/pgatss/auth.env"
log="${test_root}/invocation.log"
cli="${test_root}/vault/.agents/skills/pgatss-simulator-booking/scripts/pgatss.mjs"
: >"${cli}"
printf 'PGTSS_PASSWORD=op://Private/Test/password\n' >"${auth_env}"
chmod 600 "${auth_env}"

cat >"${test_root}/bin/op" <<'EOF'
#!/usr/bin/env bash
printf 'op:%s\n' "$*" >"${PGATSS_TEST_LOG}"
EOF
cat >"${test_root}/bin/node" <<'EOF'
#!/usr/bin/env bash
printf 'node:%s\n' "$*" >"${PGATSS_TEST_LOG}"
EOF
chmod +x "${test_root}/bin/op" "${test_root}/bin/node"

HOME="${test_root}/home" \
PATH="${test_root}/bin:${PATH}" \
PGATSS_TEST_LOG="${log}" \
PGATSS_VAULT="${test_root}/vault" \
  "${repo_root}/bin/pgatss" doctor

expected="op:run --env-file=${auth_env} -- node ${cli} doctor"
actual="$(<"${log}")"
[[ "${actual}" == "${expected}" ]] || {
  printf 'expected: %s\nactual:   %s\n' "${expected}" "${actual}" >&2
  exit 1
}

PGTSS_PASSWORD="already-injected" \
HOME="${test_root}/home" \
PATH="${test_root}/bin:${PATH}" \
PGATSS_TEST_LOG="${log}" \
PGATSS_VAULT="${test_root}/vault" \
  "${repo_root}/bin/pgatss" doctor

expected="node:${cli} doctor"
actual="$(<"${log}")"
[[ "${actual}" == "${expected}" ]] || {
  printf 'expected: %s\nactual:   %s\n' "${expected}" "${actual}" >&2
  exit 1
}
