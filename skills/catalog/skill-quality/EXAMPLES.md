# Skill Quality Examples

Detailed good/bad examples for all skill quality principles. Referenced from SKILL.md.

## Contents

- [Description Quality](#description-quality) - Writing effective skill descriptions
- [Terminology Consistency](#terminology-consistency) - Using consistent terms
- [Concrete Examples](#concrete-examples) - Runnable vs abstract examples
- [File Reference Depth](#file-reference-depth) - Keeping references one level deep
- [Time-Sensitive Information](#time-sensitive-information) - Handling version-specific content
- [Code and Script Quality](#code-and-script-quality) - Writing robust scripts
  - [Scripts Should Solve Problems](#scripts-should-solve-problems)
  - [Error Handling](#error-handling)
  - [No Voodoo Constants](#no-voodoo-constants)
  - [Package Verification](#package-verification)
  - [Path Conventions](#path-conventions)
  - [Validation Steps](#validation-steps-for-critical-operations)
  - [Feedback Loops](#feedback-loops-for-quality)
- [Workflow Quality](#workflow-quality) - Clear steps and decision trees

## Description Quality

### Good Descriptions

Specific and actionable:

```yaml
description: "Generate UV shebang templates for standalone Python scripts with dependency management"
```

```yaml
description: "Use ast-grep for syntax-aware code search in JavaScript/TypeScript"
```

```yaml
description: "Apply jujutsu (jj) version control workflows with commit stacking"
```

### Bad Descriptions

Vague or generic:

```yaml
description: "Help with Python"
```

```yaml
description: "Code search"
```

```yaml
description: "Version control stuff"
```

### What Makes Good Descriptions

**Include key terms that trigger the skill:**

- "UV shebang", "Python scripts", "dependency management"
- "ast-grep", "syntax-aware", "code search"
- "jujutsu", "jj", "commit stacking"

**Explain WHAT and WHEN:**

- WHAT: "Generate UV shebang templates"
- WHEN: "for standalone Python scripts"

## Terminology Consistency

### Good - Consistent Terms

Always use "UV shebang":

````markdown
## UV Shebang Template

Use the UV shebang format for standalone scripts.

Example UV shebang:

```python
#!/usr/bin/env -S uv run --script
```
````

When adding a UV shebang to existing code...

````

### Bad - Mixed Terms

Inconsistent terminology:

```markdown
## UV Shebang Template

Use the uv script header for standalone scripts.

Example inline script metadata:
```python
#!/usr/bin/env -S uv run --script
````

When adding a UV shebang format...

````

Notice: "uv script header", "inline script metadata", "UV shebang format" all mean the same thing but use different terms.

### Establishing Vocabulary

**Do this early in the skill:**

```markdown
# Git Workflow (Jujutsu/jj)

This skill uses jujutsu (jj) commands. Note: jj uses "change" where git uses "commit".

Throughout this skill:
- "change" = jj terminology (preferred)
- "commit" = git terminology (used for comparison only)
````

## Concrete Examples

### Good - Concrete and Runnable

Complete, copy-pasteable example:

````markdown
## UV Shebang Template

```python
#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["requests", "typer"]
# ///

import requests
import typer

def main(url: str):
    response = requests.get(url)
    print(f"Status: {response.status_code}")

if __name__ == "__main__":
    typer.run(main)
```

Save as `fetch.py`, make executable (`chmod +x fetch.py`), then run:

```bash
./fetch.py https://example.com
```

Expected output:

```
Status: 200
```
````

### Bad - Abstract Guidance

Vague, not runnable:

```markdown
## UV Shebang Template

Use the UV shebang format with inline dependencies specified in the PEP 723 format.
Include your imports and a main function.
```

## File Reference Depth

### Good - One Level Deep

```markdown
## Advanced Patterns

For detailed examples, see [examples.md](./examples.md)

For API reference, see [reference.md](./reference.md)
```

### Bad - Multiple Levels Deep

```markdown
## Advanced Patterns

See [examples.md](./examples.md) which references the patterns
in [patterns.md](./patterns.md) which has code examples in
`scripts/examples/` that demonstrate concepts from [concepts.md](./concepts.md)
```

### Fix for Multiple Levels

Create a consolidated reference:

```markdown
## Advanced Patterns

See [examples.md](./examples.md) for:

- Common patterns
- Code examples
- Conceptual explanations
- Working scripts
```

## Time-Sensitive Information

### Good - Isolated Time-Sensitive Content

````markdown
## Current Best Practice (as of 2024)

Use ast-grep for syntax-aware code searches.

### ast-grep Pattern Example

```bash
ast-grep --pattern 'function $NAME() { $$$ }'
```
````

## Legacy Patterns

Before ast-grep, ripgrep was used for all code search:

```bash
rg "function.*\(" --type js
```

This approach lacks syntax awareness and produces false positives.

````

### Bad - Implicit Time Sensitivity

```markdown
## Code Search

The new ast-grep tool just came out and is way better than ripgrep!
Everyone should use it instead.

```bash
ast-grep --pattern 'function $NAME() { $$$ }'
````

````

### Deprecation Pattern

```markdown
## ⚠️ Deprecated Pattern

The `jj git` subcommand is deprecated in jj 0.10+.
Use direct `jj` commands instead.

**Old (deprecated):**
```bash
jj git push
jj git fetch
````

**New (current):**

```bash
jj push
jj fetch
```

Migration: Replace `jj git <command>` with `jj <command>`

````

## Code and Script Quality

### Scripts Should Solve Problems

#### Good - Solves the Problem

```python
def validate_plugin_json(path: Path) -> list[str]:
    """Validate plugin.json and return specific errors."""
    errors = []

    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        return [f"Invalid JSON: {e}"]
    except FileNotFoundError:
        return [f"File not found: {path}"]

    # Check required fields
    required = ["name", "version", "description", "author"]
    for field in required:
        if field not in data:
            errors.append(f"Missing required field: {field}")

    # Validate version format (semver)
    if "version" in data:
        version = data["version"]
        if not re.match(r'^\d+\.\d+\.\d+$', version):
            errors.append(f"Invalid version format: {version} (expected: x.y.z)")

    # Validate hooks if present
    if "hooks" in data:
        if not isinstance(data["hooks"], list):
            errors.append("hooks must be an array")

    return errors
````

#### Bad - Punts to Claude

```python
def validate_plugin_json(path: Path):
    """Validate plugin.json - Claude should figure out what's wrong."""
    with open(path) as f:
        data = json.load(f)

    # TODO: add validation
    # Check for issues and report them
```

### Error Handling

#### Good - Explicit and Helpful

```python
def run_jj_command(args: list[str]) -> str:
    """Run jj command and return output with helpful error messages."""
    try:
        result = subprocess.run(
            ["jj"] + args,
            capture_output=True,
            text=True,
            check=True,
            timeout=30
        )
        return result.stdout

    except FileNotFoundError:
        print("Error: jj not found")
        print("Install with: brew install jj")
        print("Or see: https://github.com/martinvonz/jj#installation")
        sys.exit(1)

    except subprocess.TimeoutExpired:
        print(f"Error: Command timed out after 30 seconds")
        print(f"Command: jj {' '.join(args)}")
        print("This may indicate a problem with your repository")
        sys.exit(1)

    except subprocess.CalledProcessError as e:
        print(f"Error running jj command: {' '.join(args)}")
        print(f"Exit code: {e.returncode}")
        print(f"Output: {e.stderr}")
        print()
        print("Hints:")
        print("  - Are you in a jj repository? (run: jj status)")
        print("  - Is your repository in a valid state? (run: jj log)")
        sys.exit(1)
```

#### Bad - Generic Error Handling

```python
def run_jj_command(args: list[str]) -> str:
    """Run jj command."""
    try:
        result = subprocess.run(["jj"] + args, capture_output=True)
        return result.stdout.decode()
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
```

### No Voodoo Constants

#### Good - Justified Constants

```python
# Timeout for Claude API requests
# Typical requests: 5-10 seconds
# Allow 3x buffer for slow connections
TIMEOUT_SECONDS = 30

# Maximum retry attempts
# Balance between:
#   - Reliability (network hiccups)
#   - User patience (waiting time)
#   - API rate limits (avoid hammering)
MAX_RETRIES = 3

# Buffer size for streaming responses
# Large enough to avoid excessive syscalls
# Small enough to show progress quickly
# Based on typical Claude response chunk size
BUFFER_SIZE = 4096
```

#### Bad - Unexplained Magic Numbers

```python
timeout = 30
retries = 3
buffer = 4096
```

### Package Verification

#### Good - Complete Dependencies Section

````markdown
## Dependencies

This skill requires the following tools:

### ast-grep (required)

Syntax-aware code search tool.

**Install:**

```bash
# macOS
brew install ast-grep

# Linux
cargo install ast-grep

# Or download binary from:
# https://github.com/ast-grep/ast-grep/releases
```

**Verify:**

```bash
which ast-grep        # Should return path
ast-grep --version    # Should show version
```

### ripgrep (optional)

Fast text search, useful for preliminary filtering.

**Install:**

```bash
brew install ripgrep  # Usually pre-installed on macOS
```

**Verify:**

```bash
which rg
```
````

#### Bad - Missing Installation Steps

```markdown
## Dependencies

You need ast-grep and ripgrep.
```

### Path Conventions

#### Good - Forward Slashes

````markdown
## Plugin Location

```bash
config/claude/plugins/my-plugin/.claude-plugin/plugin.json
```
````

For cross-platform paths:

- macOS/Linux: `~/.config/claude/plugins/`
- Windows: `%USERPROFILE%/.config/claude/plugins/` (use forward slashes)

````

#### Bad - Backslashes

```markdown
## Plugin Location

```bash
config\claude\plugins\my-plugin\.claude-plugin\plugin.json
````

`````

### Validation Steps for Critical Operations

#### Good - Verification at Each Step

````markdown
## Creating a New Plugin

1. **Create directory structure:**
   ```bash
   mkdir -p config/claude/plugins/my-plugin/.claude-plugin/hooks
`````

**Verify:**

```bash
ls -la config/claude/plugins/my-plugin/
# Should show .claude-plugin/ directory
```

2. **Create plugin.json:**

   ```bash
   cat > config/claude/plugins/my-plugin/.claude-plugin/plugin.json << 'EOF'
   {
     "name": "my-plugin",
     "version": "0.1.0",
     "description": "My plugin description",
     "author": "Your Name"
   }
   EOF
   ```

   **Verify:**

   ```bash
   cat config/claude/plugins/my-plugin/.claude-plugin/plugin.json
   # Should show valid JSON

   jq '.' config/claude/plugins/my-plugin/.claude-plugin/plugin.json
   # Should parse without errors
   ```

3. **Test the plugin:**

   ```bash
   claude plugin validate config/claude/plugins/my-plugin/
   ```

   **Expected output:**

   ```
   ✅ Plugin is valid
   ✅ All required fields present
   ✅ Version format correct
   ```

   **If errors occur:**
   - Check JSON syntax: `jq '.' plugin.json`
   - Verify required fields: name, version, description, author
   - Check file permissions: `ls -l plugin.json`

`````

#### Bad - No Verification

```markdown
## Creating a New Plugin

1. Create directory
2. Create plugin.json
3. Test

Done!
```

### Feedback Loops for Quality

#### Good - Explicit Verification Checklist

```markdown
## Writing Commit Messages

After generating a commit message, verify:

- [ ] **Accuracy**: Message describes what actually changed
- [ ] **Format**: Follows conventional commit format (`feat:`, `fix:`, etc.)
- [ ] **Length**: Summary line is under 72 characters
- [ ] **Detail**: Body explains why (not just what)
- [ ] **References**: Mentions related issues/PRs if applicable

**If any check fails:**
1. Identify which criteria failed
2. Request regeneration with specific corrections:
   ```
   "Regenerate commit message: make summary line shorter and add 'why' context"
   ```
3. Re-verify all criteria

**Example verification:**
```bash
# Check message length
git log -1 --pretty=%s | wc -c
# Should be <= 72

# Check format
git log -1 --pretty=%s | grep -E '^(feat|fix|docs|style|refactor|test|chore):'
# Should match pattern
```
```

#### Bad - No Verification Process

```markdown
## Writing Commit Messages

Claude will generate a good commit message.
```

## Workflow Quality

### Clear Step Structure

#### Good - Numbered Steps with Verification

````markdown
## Setting Up a New Repository

1. **Initialize repository:**
   ```bash
   jj init --git my-project
   cd my-project
   ```

   **Verify:** `jj status` should show "working copy clean"

2. **Create initial commit:**
   ```bash
   jj describe -m "Initial commit"
   jj new
   ```

   **Verify:**
   ```bash
   jj log
   # Should show two commits: initial and working copy
   ```

3. **Configure remote:**
   ```bash
   jj git remote add origin git@github.com:user/my-project.git
   ```

   **Verify:**
   ```bash
   jj git remote -v
   # Should show origin URL
   ```

4. **Push to remote:**
   ```bash
   jj git push
   ```

   **Expected output:**
   ```
   Branch changes to push to origin:
     Add branch main to <commit-id>
   ```
`````

#### Bad - Unclear Steps

````markdown
## Setting Up

Initialize the repo, make a commit, add a remote, and push.

```bash
jj init --git my-project
jj describe -m "Initial commit"
jj git remote add origin <url>
jj git push
```
````

````

### Decision Trees for Workflows

#### Good - Clear Decision Points

```markdown
## Choosing the Right Search Tool

**Need to find code by syntax structure?**
- Example: "Find all React components"
- Example: "Find all functions named `validate*`"
→ **Use ast-grep**: `ast-grep --pattern 'function $NAME() { $$$ }'`

**Need to find code by text content?**
- Example: "Find all files mentioning API keys"
- Example: "Find TODOs in comments"
→ **Use ripgrep**: `rg "TODO" --type js`

**Need to combine structure and content?**
- Example: "Find async functions that call fetch"
→ **Use both:**
  1. First, find files with fetch: `rg "fetch" --type js --files-with-matches`
  2. Then, search those files: `ast-grep --pattern 'async function $F() { $$$ fetch($$$) $$$ }'`

**Not sure which to use?**
→ Start with ripgrep (faster), then refine with ast-grep if needed
````

#### Bad - Vague Guidance

```markdown
## Choosing the Right Tool

Use ast-grep for structural searches and ripgrep for text searches.
Sometimes you might want to use both.
```
