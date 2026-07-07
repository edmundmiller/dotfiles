# Pytest Checklist

Use this when a pytest task needs more than the core loop in `SKILL.md`.

## Contract

- Name the user-visible behavior: return value, exception, file content, CLI output, serialized record, or side effect.
- Read `pyproject.toml` or `pytest.ini` before choosing markers and commands.
- Prefer public functions and CLIs. Test private helpers only for standalone scripts where they are the practical seam.

## State

- Use `tmp_path` for filesystem effects.
- Use `monkeypatch` for env vars, cwd, attributes, and network clients.
- Put shared fixtures in `conftest.py` only after multiple files need them.

## Assertions

- Use `pytest.raises(..., match=...)` for user-facing errors.
- Parametrize one real behavior matrix; skip speculative edge farms.
- Use strict `xfail` only to keep a regression-test commit green before the fix.

## Command

- Prefer the repo's documented command.
- Otherwise run `uv run pytest path/to/test.py -q` when uv is present, or `python -m pytest path/to/test.py -q`.
