# Testing Claude Code Plugin Hooks

Guide for writing tests for Claude Code plugin hooks with pytest and UV.

## Hook Types and I/O Format

Claude Code hooks receive JSON via stdin and return JSON via stdout.

### Command Hooks (`type: "command"`)

**Input:** Event data with tool information

```json
{
  "tool": {
    "name": "Bash",
    "params": {
      "command": "git commit -m 'test'"
    }
  }
}
```

**Output:** Decision with optional system message

```json
{
  "continue": false,
  "system_message": "Use jj instead of git"
}
```

### Prompt Hooks (`type: "prompt"`)

**Input:** Event data with user message

```json
{
  "userMessage": "Can you help me debug this?"
}
```

**Output:** Decision with reason

```json
{
  "decision": "approve",
  "reason": "No scope shift detected",
  "continue": true,
  "systemMessage": "Optional context for Claude"
}
```

## Test File Structure

Use UV shebang with pytest for self-executing tests:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["pytest"]
# ///
"""Test description."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

# Fixtures
@pytest.fixture
def hook_path():
    return Path(__file__).parent / "my-hook.py"

# Tests
def test_hook_returns_valid_json(hook_path):
    """Hook should return valid JSON."""
    event = {"tool": {"name": "Bash", "params": {"command": "test"}}}

    result = subprocess.run(
        [str(hook_path)],
        input=json.dumps(event),
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0
    response = json.loads(result.stdout)
    assert "continue" in response

# Self-execution
if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
```

## Testing Patterns

### Pattern 1: Test via subprocess (recommended)

Simulates how Claude Code actually calls hooks:

```python
def test_hook_blocks_command(hook_path):
    event = {"tool": {"name": "Bash", "params": {"command": "dangerous"}}}

    result = subprocess.run(
        [str(hook_path)],
        input=json.dumps(event),
        capture_output=True,
        text=True,
    )

    response = json.loads(result.stdout)
    assert response["continue"] is False
```

### Pattern 2: Test multiple scenarios

```python
@pytest.mark.parametrize("command,should_block", [
    ("git commit", True),
    ("git log", False),
    ("ls", False),
])
def test_command_blocking(hook_path, command, should_block):
    event = {"tool": {"name": "Bash", "params": {"command": command}}}
    result = subprocess.run(
        [str(hook_path)],
        input=json.dumps(event),
        capture_output=True,
        text=True,
    )

    response = json.loads(result.stdout)
    assert response["continue"] != should_block
```

### Pattern 3: Test JSON validation

```python
def test_hook_always_returns_valid_json(hook_path):
    """Hook should never crash, always return valid JSON."""
    edge_cases = [
        {},  # Empty event
        {"tool": {}},  # Missing params
        {"tool": {"name": "Unknown"}},  # Unknown tool
    ]

    for event in edge_cases:
        result = subprocess.run(
            [str(hook_path)],
            input=json.dumps(event),
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
        json.loads(result.stdout)  # Should not raise
```

## Common Tests to Write

### For PreToolUse/PostToolUse hooks:

1. ✓ Returns valid JSON structure
2. ✓ Handles missing/malformed input
3. ✓ Correct tool matcher behavior
4. ✓ Condition regex works correctly

### For UserPromptSubmit/Stop hooks:

1. ✓ Returns required fields (decision, reason, continue)
2. ✓ Decision is valid ("approve" or "deny")
3. ✓ Handles empty/missing user messages
4. ✓ Proper timeout handling

## Minimal Testing Philosophy

**Only test what you need right now:**

- Core functionality that must work
- Edge cases you've encountered
- Regression tests for fixed bugs

**Don't test:**

- Every possible input combination
- Obvious Python/library behavior
- Features you haven't implemented

**When something breaks:**

1. Write a minimal test that reproduces the issue
2. Fix the code to make the test pass
3. Move on

## Running Tests

```bash
# Self-execute
./test_hooks.py

# Via pytest
pytest test_hooks.py -v

# Specific test
pytest test_hooks.py::test_hook_returns_valid_json -v

# With coverage
pytest test_hooks.py --cov=. -v
```

## Example: Real World Test File

See `config/claude/plugins/jj/hooks/test_hooks.py` for a complete example testing:

- Git command blocking
- Read-only command allowing
- JSON validation
- Multiple hook types

## Debugging Failed Tests

**Hook returns wrong JSON:**

```bash
echo '{"tool":{"name":"Bash","params":{"command":"test"}}}' | ./my-hook.py | jq
```

**Hook crashes:**

```bash
echo '{}' | ./my-hook.py
# Check stderr for error messages
```

**Test JSON parsing:**

```python
import json
response = json.loads(result.stdout)
print(json.dumps(response, indent=2))
```
