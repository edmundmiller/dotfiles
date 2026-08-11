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
