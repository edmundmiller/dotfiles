---
name: pytest
description: Use when writing pytest tests, fixtures, monkeypatch, xfail, or pytest runs.
---

# Pytest

Pytest work should be **contract-first**: exercise the public behavior, keep fixtures boring, and run the smallest command that proves the change.

## When to Use

- Writing or changing Python tests that use pytest.
- Choosing fixtures, `tmp_path`, `monkeypatch`, parametrization, or strict `xfail`.
- Selecting the narrowest `pytest` command for a red/green loop.

## Loop

1. **Find the contract.** Read the target module, existing tests, and `pyproject.toml`/`pytest.ini` test config. Stop when the public behavior and target command are clear.

2. **Write one red test.** For bugs, encode the reported failure directly. Use `pytest.mark.xfail(strict=True, reason="...")` only for a separate regression-test commit that must stay green before the fix.

3. **Choose the seam.** Prefer public functions, CLI commands, file outputs, exceptions, or serialized data. Test private helpers only when the file is a standalone script and the helper is the practical public seam.

4. **Control state.** Use `tmp_path`, `monkeypatch`, fixtures, and small in-memory fakes. Avoid real home directories, real network calls, wall-clock time, and persistent global state.

5. **Assert behavior.** Check exact outputs, parsed structures, exceptions, file contents, and ordering when order is the contract. Avoid assertions that only mirror implementation steps.

6. **Run narrow.** Use the repo's existing command if present, otherwise `uv run pytest <file> -q` or `pytest <file> -q`. Completion criterion: the test proves the behavior red before the fix and green after.

## House style

- Keep test data small and readable. Use fixture files only when inline data hides the behavior.
- Put shared fixtures in `conftest.py` only after more than one test file needs them.
- Use parametrization for one behavior across a real input matrix; do not create speculative edge-case farms.
- Prefer `tmp_path` over `tempfile` unless the code requires a raw temporary file API.
- Use `monkeypatch.setenv`, `monkeypatch.setattr`, and `monkeypatch.chdir` so cleanup is automatic.
- Assert exceptions with `pytest.raises(..., match=...)` when the message is user-facing or diagnostic.
- Mark slow or external tests with the repo's existing marker, e.g. `integration`; keep default runs offline and fast.
- Do not silence failures with broad `try/except`. If the behavior is "does not crash", call it and let pytest show the unexpected exception.

## Patterns

### Fixture file reader

```python
from pathlib import Path
import json
import pytest

FIXTURES = Path(__file__).parent / "fixtures"

@pytest.fixture
def basic_payload():
    return json.loads((FIXTURES / "basic_payload.json").read_text())
```

### Temporary output contract

```python
def test_writes_archive_record(tmp_path):
    out = tmp_path / "archive"

    result = write_archive(out, {"role": "user", "content": "hello"})

    assert result == out / "conversation.jsonl"
    assert result.read_text().splitlines() == ['{"role": "user", "content": "hello"}']
```

### Strict regression marker

```python
import pytest

@pytest.mark.xfail(strict=True, reason="BUG-123: malformed JSON should preserve raw input")
def test_malformed_json_preserves_raw():
    assert parse_arguments("{broken") == {"raw": "{broken"}
```

## Commands

- Specific test: `uv run pytest tests/test_name.py -q`.
- Specific case: `uv run pytest tests/test_name.py::test_case -q`.
- Existing project command wins when `pyproject.toml`, README, or CI defines one.
- Use `-vv` only when assertion detail is needed; default to quiet output for quick loops.
