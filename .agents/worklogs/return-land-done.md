# Worklog: return-land-done

Status: complete

## Objective

Provide an explicitly invoked clean publication lane that integrates named Git
revisions from an isolated authoritative clone, preserves the source checkout
byte-for-byte, handles one remote race, and proves authoritative default-tip
equality with structured JSON.

## Decisions

- Keep the source checkout read-only; all fetch, replay, reset, push, and proof
  operations occur in a disposable clone.
- Use ordinary push as the remote serialization boundary. A single
  non-fast-forward rejection is reconciled and retried once; another rejection
  blocks without force or no-verify options.
- Keep the lane separate from automatic `$done` fallback because project
  policy may prohibit the publication write.
- Redact credential-bearing HTTP(S)/SSH URLs from command errors.
- Resolve the default branch from authoritative remote `ls-remote` output;
  cached remote-tracking HEAD metadata may be stale.

## Evidence

- Red tests specify dirty-source preservation and one-race replay behavior.
- Green tests cover source HEAD/branch/index/tracked/untracked preservation,
  task replay, competitor preservation, default discovery, and structured
  credential-safe failure output.
- `python3 -m unittest tests/test_done_closeout.py tests/test_done_skill.py`
  passed all 22 tests.
- The stale cached `origin/HEAD=main` versus authoritative remote `HEAD=develop`
  regression proved publication targets `develop` only.
- `python3 -m py_compile skills/catalog/done/scripts/publish-clean.py` and
  `git diff --check` passed.

## Reviews

- Parent review requested preservation of the base file in the race test and
  credential redaction in errors; both are included.

## Feedback

The lane's remote normal push is the serialization mechanism; no canonical
checkout lock is required because rejection causes bounded reclassification.

## Remaining work

None.

## Commits

- `160b23a2f` — expected-failure clean publication contract.
- Green implementation, documentation, and regression tests — this commit.
- `005c36fa9` — expected-failure authoritative-default regression.
- Green authoritative-default fix and regression — this commit.
