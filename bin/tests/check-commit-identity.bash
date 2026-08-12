#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT

git -C "${test_root}" init -q
git -C "${test_root}" config user.name "Edmund Miller"
git -C "${test_root}" config user.email "20095261+edmundmiller@users.noreply.github.com"
printf 'good\n' >"${test_root}/file"
git -C "${test_root}" add file
git -C "${test_root}" commit -qm good
good="$(git -C "${test_root}" rev-parse HEAD)"

(
  cd "${test_root}"
  "${repo_root}/bin/check-commit-identity" "${good}^!"
)

printf 'bad\n' >"${test_root}/file"
git -C "${test_root}" add file
git -C "${test_root}" -c user.name="Test User" -c user.email="test@example.com" commit -qm bad
bad="$(git -C "${test_root}" rev-parse HEAD)"

if (
  cd "${test_root}"
  "${repo_root}/bin/check-commit-identity" "${bad}^!"
) 2>/dev/null; then
  echo "expected Test User commit to be rejected" >&2
  exit 1
fi

git -C "${test_root}" branch bad-local "${bad}"
git -C "${test_root}" switch -q -c push-good "${good}"
printf 'push-good\n' >"${test_root}/file"
git -C "${test_root}" add file
git -C "${test_root}" commit -qm push-good
push_good="$(git -C "${test_root}" rev-parse HEAD)"

# Expected failure until the pre-push check honors the range supplied by the
# hook runner instead of scanning unrelated local refs.
if (
  cd "${test_root}"
  PRE_COMMIT_FROM_REF="${good}" PRE_COMMIT_TO_REF="${push_good}" \
    "${repo_root}/bin/check-commit-identity"
) 2>/dev/null; then
  echo "identity check unexpectedly ignored the known range-scoping bug" >&2
  exit 1
fi
