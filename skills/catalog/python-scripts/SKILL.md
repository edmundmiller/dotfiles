---
name: python-scripts
description: Use when writing standalone Python scripts (one-off scripts, utilities, not part of a larger Python project with pyproject.toml or setup.py). Provides UV shebang template and best practices.
---

# Standalone Python Scripts

## UV Shebang Template

For standalone Python scripts, always use the UV shebang format:

```python
#!/usr/bin/env -S uv run --script
#
# /// script
# dependencies = [
#   "requests",
#   "click",
# ]
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///

import requests
import click

# Your script code here
```

## Key Points

- **Self-contained:** All dependencies declared in the file
- **No virtual env needed:** UV handles dependencies automatically
- **Execution:** Run directly with `uv run script.py` or `./script.py` (if executable)
- **Date pinning:** The `exclude-newer` ensures reproducible builds
- **PEP 723 compliant:** Uses the inline script metadata standard

## When to Use

✅ **Use this for:**

- One-off automation scripts
- CLI utilities
- Data processing scripts
- Quick prototypes
- Scripts without a containing project

❌ **Don't use this for:**

- Files in a project with `pyproject.toml` or `setup.py`
- Modules meant to be imported
- Production services/applications

## Example Script

```python
#!/usr/bin/env -S uv run --script
#
# /// script
# dependencies = [
#   "httpx",
#   "rich",
# ]
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///

import httpx
from rich import print

def main():
    response = httpx.get("https://api.github.com")
    print(f"Status: {response.status_code}")

if __name__ == "__main__":
    main()
```

## Making Scripts Executable

```bash
chmod +x script.py
./script.py  # Run directly
```
