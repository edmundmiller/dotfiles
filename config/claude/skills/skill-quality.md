---
description: "Apply best practices checklist when creating or reviewing Claude Code skills"
priority: 5
---

# Skill Quality Validation

Use this skill when creating new Claude Code skills or reviewing existing ones to ensure they follow best practices and are effective for users.

## When to Use This Skill

- Creating a new skill from scratch
- Reviewing an existing skill for quality improvements
- Debugging why a skill isn't being invoked correctly
- Preparing a skill for sharing or publication
- After receiving feedback that a skill isn't working well

## Core Quality Checklist

### Description Quality

**Check the skill description (frontmatter):**

✅ **Good descriptions** are specific and actionable:

```yaml
description: "Generate UV shebang templates for standalone Python scripts with dependency management"
```

❌ **Bad descriptions** are vague or generic:

```yaml
description: "Help with Python"
```

**Requirements:**

- Include key terms that trigger the skill (e.g., "UV shebang", "Python scripts")
- Explain both WHAT it does and WHEN to use it
- Keep under 100 characters if possible
- Use terms the user would naturally say

### Content Structure

**SKILL.md body must be:**

- Under 500 lines total
- Well-organized with clear sections
- Using progressive disclosure (most important info first)
- Concrete examples, not abstract theory

**If your skill exceeds 500 lines:**

1. Split into multiple related files
2. Keep core guidance in SKILL.md
3. Move reference material to separate files
4. Link to additional files when needed

**Recommended skill directory structure:**

```
my-skill/
├── SKILL.md              # Main instructions (loaded when triggered)
├── reference.md          # API/command reference (loaded as needed)
├── examples.md           # Usage examples (loaded as needed)
├── patterns.md           # Common patterns (loaded as needed)
└── scripts/
    ├── analyze.py        # Utility script (executed, not loaded)
    ├── process.py        # Processing script
    └── validate.py       # Validation script
```

**File purposes:**

- `SKILL.md` - Core guidance, always loaded when skill triggers
- `reference.md` - Detailed API/command reference, link from SKILL.md
- `examples.md` - Extended examples, link when user needs more
- `patterns.md` - Advanced patterns, optional deep-dive content
- `scripts/` - Executable utilities, not loaded as context

**Example skill with multiple files:**

```
pdf/
├── SKILL.md              # "Use this skill for PDF operations..."
├── FORMS.md              # "How to fill PDF forms..."
├── reference.md          # "Complete API reference..."
├── examples.md           # "Example: Extract tables from PDF..."
└── scripts/
    ├── analyze_form.py   # Script to analyze form fields
    ├── fill_form.py      # Script to fill forms
    └── validate.py       # Script to validate PDFs
```

**Key principles:**

- SKILL.md stays under 500 lines by referencing other files
- Related files use UPPERCASE for visibility (FORMS.md, not forms.md)
- Scripts are in subdirectory and executed, not loaded as context
- Each file has a single, clear purpose

**Progressive disclosure pattern:**

```markdown
# Skill Name

Brief intro (1-2 sentences)

## When to Use

Quick bullet list

## Quick Reference

Most common cases with examples

## Detailed Guidance

Deeper explanations

## Edge Cases

(Optional) Advanced scenarios
```

### Terminology Consistency

**Use consistent terms throughout:**

✅ Good:

- Always use "UV shebang" (not mixing "UV shebang", "uv script header", "inline script metadata")
- Always use "plugin.json" (not mixing "plugin config", "plugin.json", "manifest file")

❌ Bad:

- Switching between "git commit" and "create commit" and "add commit"
- Using "repo" and "repository" interchangeably without establishing the synonym

**Establish vocabulary early:**

```markdown
# Git Workflow (Jujutsu/jj)

This skill uses jujutsu (jj) commands. Note: jj uses "change" where git uses "commit".
```

### Examples Must Be Concrete

**Every pattern must have a real example:**

✅ Good:

````markdown
## UV Shebang Template

```python
#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["requests", "typer"]
# ///
```
````

Use this for standalone scripts that need external dependencies.

````

❌ Bad:
```markdown
## UV Shebang Template

Use the UV shebang format with inline dependencies.
````

### File Reference Depth

**Keep file references one level deep maximum:**

✅ Good:

```markdown
See `config/claude/skills/python-scripts.md` for templates
```

❌ Bad:

```markdown
See `config/claude/skills/python-scripts.md` which references the patterns in `config/claude/skills/python-patterns/async.md` which has examples in `config/claude/skills/python-patterns/async-examples/`
```

**If you need multiple levels:**

1. Create a single consolidated reference document
2. Or use progressive disclosure within one file

### Time-Sensitive Information

**Avoid or isolate time-sensitive content:**

✅ Good:

```markdown
## Current Best Practice (as of 2024)

Use ast-grep for syntax-aware searches.

## Legacy Patterns

Previously, ripgrep was used for all code search...
```

❌ Bad:

```markdown
The new ast-grep tool just came out and is better than ripgrep!
```

**Handle deprecation explicitly:**

```markdown
## ⚠️ Deprecated Pattern

The `jj git` subcommand is deprecated in jj 0.10+.
Use `jj` commands directly instead.

Old: `jj git push`
New: `jj push`
```

## Code and Script Quality

### Scripts Should Solve Problems

**Don't punt to Claude - solve it:**

✅ Good:

```python
def validate_plugin_json(path: Path) -> list[str]:
    """Validate plugin.json and return specific errors."""
    errors = []
    with open(path) as f:
        data = json.load(f)

    if "name" not in data:
        errors.append("Missing required field: name")
    if "version" not in data:
        errors.append("Missing required field: version")

    return errors
```

❌ Bad:

```python
def validate_plugin_json(path: Path):
    """Validate plugin.json - Claude should figure out what's wrong."""
    with open(path) as f:
        data = json.load(f)
    # TODO: add validation
```

### Error Handling Must Be Explicit

**Every error path should have helpful messages:**

✅ Good:

```python
try:
    result = subprocess.run(["jj", "status"], capture_output=True, check=True)
except FileNotFoundError:
    print("Error: jj not found. Install with: brew install jj")
    sys.exit(1)
except subprocess.CalledProcessError as e:
    print(f"Error running jj: {e.stderr.decode()}")
    print("Hint: Are you in a jj repository?")
    sys.exit(1)
```

❌ Bad:

```python
result = subprocess.run(["jj", "status"], capture_output=True)
# Hope it works!
```

### No Voodoo Constants

**Every magic number needs justification:**

✅ Good:

```python
TIMEOUT_SECONDS = 30  # Claude API requests typically take 5-10s, allow 3x buffer
MAX_RETRIES = 3       # Balance between reliability and user patience
```

❌ Bad:

```python
timeout = 30
retries = 3
```

### Package Verification

**List and verify all required packages:**

````markdown
## Dependencies

This skill requires:

- `ast-grep` - Install: `brew install ast-grep` or `cargo install ast-grep`
- `ripgrep` - Install: `brew install ripgrep` (usually pre-installed)

Verify installation:

```bash
which ast-grep  # Should return path
which rg        # Should return path
```
````

### Path Conventions

**Always use forward slashes:**

✅ Good:

```markdown
config/claude/plugins/jj/commands/commit.md
```

❌ Bad:

```markdown
config\claude\plugins\jj\commands\commit.md # Windows-style
```

**Even in Windows-specific guidance, show both:**

```markdown
## File Location

Unix/Mac: `~/.config/claude/skills/`
Windows: `%USERPROFILE%/.config/claude/skills/` (use forward slashes)
```

### Validation Steps for Critical Operations

**Critical operations need verification:**

````markdown
## Committing Changes

1. Stage your files:
   ```bash
   jj describe -m "Your message"
   ```
````

2. Verify the commit:

   ```bash
   jj log -r @  # Should show your new commit
   jj show      # Review the changes
   ```

3. If incorrect, undo:
   ```bash
   jj undo
   ```

````

### Feedback Loops for Quality

**Quality-critical tasks need feedback:**

```markdown
## Writing Commit Messages

After generating a message, verify:
- [ ] Message accurately describes the changes
- [ ] Message follows conventional commit format
- [ ] Message is under 72 characters
- [ ] Related changes are mentioned

If any check fails, regenerate with corrections.
````

## Workflow Quality

### Clear Step Structure

**Use numbered steps with verification:**

````markdown
## Creating a New Plugin

1. **Create directory structure:**
   ```bash
   mkdir -p config/claude/plugins/my-plugin/.claude-plugin/hooks
   ```
````

Verify: `ls config/claude/plugins/my-plugin/.claude-plugin/`

2. **Create plugin.json:**

   ```bash
   cat > config/claude/plugins/my-plugin/.claude-plugin/plugin.json << 'EOF'
   {
     "name": "my-plugin",
     "version": "0.1.0",
     ...
   }
   EOF
   ```

   Verify: `cat config/claude/plugins/my-plugin/.claude-plugin/plugin.json`

3. **Test the plugin:**
   ```bash
   claude plugin validate config/claude/plugins/my-plugin/
   ```
   Expected output: "✅ Plugin is valid"

````

### Decision Trees for Workflows

**Complex workflows need decision points:**

```markdown
## Choosing Search Tool

**Need to find code by structure?** (e.g., "all functions named X")
→ Use ast-grep: `ast-grep --pattern 'function $NAME() { $$$ }'`

**Need to find code by text?** (e.g., "all files mentioning API")
→ Use ripgrep: `rg "API" --type js`

**Need both structure AND text?**
1. First narrow with ripgrep to find candidate files
2. Then use ast-grep on those files for precise matching
````

## Testing Guidelines

### Create Evaluation Scenarios

**Every skill needs test cases:**

```markdown
## Skill Evaluation Scenarios

Test this skill with:

1. **Simple case:** User asks "create a Python script"

   - Expected: Skill provides UV shebang template
   - Verify: Template includes dependencies section

2. **Edge case:** User asks "script without dependencies"

   - Expected: Skill provides minimal UV shebang
   - Verify: No empty dependencies array

3. **Complex case:** User asks "async script with multiple dependencies"
   - Expected: Skill provides UV shebang with async example
   - Verify: Dependencies include async-compatible packages
```

### Model Testing

**Test with all supported models:**

1. **Haiku** (fast, basic reasoning)

   - Test simple, common scenarios
   - Verify skill is invoked correctly
   - Check response quality is acceptable

2. **Sonnet** (balanced)

   - Test moderate complexity scenarios
   - Verify detailed guidance is followed
   - Check examples are used correctly

3. **Opus** (complex reasoning)
   - Test edge cases and complex scenarios
   - Verify advanced guidance is applied
   - Check creative solutions are appropriate

### Real Usage Testing

**Test in actual workflows:**

```markdown
## Real Usage Tests

Before publishing, test:

1. Create something using only the skill guidance (no external research)
2. Ask a colleague to use the skill without explanation
3. Try the skill in a new project (not the one it was developed in)
4. Test error paths by intentionally triggering failures
```

## Common Issues and Fixes

### Skill Not Being Invoked

**Problem:** Skill exists but Claude doesn't use it

**Fixes:**

1. Check description has trigger keywords
2. Increase priority (1-10, higher = more likely)
3. Make description more specific
4. Verify SKILL.md is in correct location

**Example fix:**

```yaml
# Before
description: "Help with code"
priority: 3

# After
description: "Use ast-grep for syntax-aware code search in JavaScript/TypeScript"
priority: 7
```

### Skill Too Broad

**Problem:** Skill tries to cover too many topics

**Fix:** Split into focused skills

```markdown
# Before: "python-development.md" (2000 lines covering everything)

# After: Split into focused skills

- python-scripts.md (UV shebang and standalone scripts)
- python-testing.md (pytest and test patterns)
- python-async.md (asyncio patterns)
```

### Skill Too Abstract

**Problem:** Users don't understand when to use it

**Fix:** Add concrete "when to use" section with examples

```markdown
## When to Use This Skill

Use this skill when you see these patterns:

✅ **Yes, use this skill:**

- "Create a Python script to process files"
- "I need a standalone Python tool"
- "How do I add dependencies to a Python script?"

❌ **No, different skill:**

- "Debug my Python code" → Use debugging skill
- "Optimize this algorithm" → Use performance skill
```

## Quality Self-Check

Before considering a skill complete, verify:

1. **Can someone use this skill without asking follow-up questions?**

   - If no: Add more concrete examples

2. **Would this skill work in 6 months?**

   - If no: Move time-sensitive info to "current practices" section

3. **Is every example copy-pasteable and runnable?**

   - If no: Complete all examples with working code

4. **Can you find specific guidance in under 30 seconds?**

   - If no: Improve structure and section headers

5. **Are error messages helpful enough to fix the problem?**
   - If no: Add more context and hints to errors
