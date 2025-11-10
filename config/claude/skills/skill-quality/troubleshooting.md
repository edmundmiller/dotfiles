# Skill Troubleshooting Guide

Common issues when creating Claude Code skills and how to fix them. Referenced from SKILL.md.

## Contents

- [Skill Not Being Invoked](#skill-not-being-invoked) - Description and metadata issues
- [Skill Too Broad](#skill-too-broad) - When to split skills
- [Skill Too Abstract](#skill-too-abstract) - Adding concrete guidance
- [Quality Self-Check Failures](#quality-self-check-failures) - Fixing common issues
  - [Can't use without follow-up questions](#can-someone-use-this-without-follow-up-questions)
  - [Won't work in 6 months](#would-this-work-in-6-months)
  - [Examples not runnable](#are-examples-copy-pasteable-and-runnable)
  - [Can't find guidance quickly](#can-you-find-guidance-in--30-seconds)
  - [Error messages unclear](#are-error-messages-helpful-enough)
- [Maintenance Issues](#maintenance-issues) - Keeping skills up-to-date

## Skill Not Being Invoked

**Problem:** Skill exists but Claude doesn't use it

### Diagnosis

Check these areas:

1. **Description lacks trigger keywords**

   ```yaml
   # Current
   description: "Help with Python"
   # Problem: Too vague, no specific triggers
   ```

2. **Priority too low**

   ```yaml
   priority: 1 # Rarely invoked
   ```

3. **Wrong file location**

   ```
   config/claude/skills/my-skill/README.md  # ❌ Wrong
   config/claude/skills/my-skill/SKILL.md   # ✅ Correct
   ```

4. **Missing or malformed frontmatter**

   ```markdown
   # Missing the YAML frontmatter entirely

   # Or:

   --
   description: "Test" # ❌ Wrong (single dash)
   --
   ```

### Fixes

**Fix 1: Add specific trigger keywords**

```yaml
# Before
description: "Help with Python"
priority: 3

# After
description: "Generate UV shebang templates for standalone Python scripts with dependency management"
priority: 7
```

**What changed:**

- Added "UV shebang" (technical term users will say)
- Added "standalone Python scripts" (common phrase)
- Added "dependency management" (key use case)
- Increased priority to 7 (important skill)

**Fix 2: Verify file structure**

```bash
# Check file exists at correct location
ls -la config/claude/skills/my-skill/SKILL.md

# Check frontmatter format
head -n 5 config/claude/skills/my-skill/SKILL.md
# Should show:
# ---
# description: "..."
# priority: N
# ---
```

**Fix 3: Test invocation**

Ask Claude questions that should trigger the skill:

```
# Test 1: Direct technical term
"Create a UV shebang script"

# Test 2: Common phrase
"I need a standalone Python script"

# Test 3: Use case
"How do I add dependencies to a Python script?"
```

If skill still not invoked:

- Check spelling in description
- Try more common/natural phrases
- Increase priority to 8 or 9

## Skill Too Broad

**Problem:** Skill tries to cover too many topics, becomes unwieldy and hard to maintain

### Diagnosis

Signs of too-broad skill:

- SKILL.md exceeds 1000 lines
- Covers multiple unrelated topics
- User confusion about when to use it
- Frequent updates needed for unrelated reasons

### Example

```markdown
# python-development.md (2000 lines)

## Contents

- Virtual environments
- Package management
- Testing
- Linting
- Type checking
- Async programming
- Web frameworks
- Database access
- CLI tools
- Scripts
- Jupyter notebooks
- ...
```

**Problem:** This is a Python encyclopedia, not a focused skill.

### Fix: Split into Focused Skills

```markdown
# Split into focused skills:

python-scripts.md # UV shebang and standalone scripts
python-testing.md # pytest and test patterns
python-async.md # asyncio patterns
python-cli.md # typer and click patterns
python-typing.md # type hints and mypy
```

**Benefits of splitting:**

- Each skill under 500 lines
- Clear invocation triggers
- Focused guidance
- Easier to maintain
- Less context overhead

### How to Split

1. **Identify natural boundaries:**

   - By tool (pytest, mypy, typer)
   - By use case (scripts, APIs, CLIs)
   - By pattern (async, typing, error handling)

2. **Create directory structure:**

   ```bash
   mkdir -p config/claude/skills/{python-scripts,python-testing,python-async}
   ```

3. **Move content:**

   - Copy relevant sections to new skills
   - Update cross-references
   - Remove from original

4. **Update descriptions:**

   ```yaml
   # python-scripts/SKILL.md
   description: "UV shebang templates for standalone Python scripts"

   # python-testing/SKILL.md
   description: "Pytest patterns and test organization"
   ```

5. **Add cross-references:**

   ```markdown
   ## Related Skills

   - For async patterns, see python-async skill
   - For testing, see python-testing skill
   ```

## Skill Too Abstract

**Problem:** Users don't understand when or how to use the skill

### Diagnosis

Signs of too-abstract skill:

- Lacks concrete examples
- Uses jargon without explanation
- No "when to use" section
- Users ask follow-up questions
- Examples are toy/academic

### Example

```markdown
## Code Search

Use the appropriate search tool based on your needs.
Consider structural vs textual search requirements.
Apply the right patterns for your use case.
```

**Problems:**

- What are "structural vs textual" searches?
- Which tool is "appropriate" when?
- What are the "right patterns"?
- No examples

### Fix: Add Concrete "When to Use" Section

```markdown
## When to Use This Skill

Use this skill when you see these patterns:

### ✅ Yes, use this skill for:

**Finding code by structure:**

- "Find all React components"
- "Find all functions named `validate*`"
- "Show me all class definitions"

**Finding code by content:**

- "Find all files mentioning API keys"
- "Search for TODO comments"
- "Find error messages containing 'failed'"

**Combining structure and content:**

- "Find async functions that call fetch"
- "Find React components that use useState"

### ❌ No, use different skills for:

**Debugging code:**

- "Why is this function failing?" → Use debugging skill
- "This code has a bug" → Use debugging skill

**Code optimization:**

- "Make this faster" → Use performance skill
- "Reduce memory usage" → Use performance skill

**Code refactoring:**

- "Restructure this module" → Use refactoring skill
- "Extract this into a function" → Use refactoring skill
```

### Add Runnable Examples

````markdown
## Examples

### Find React Components

**Task:** Find all React components in project

**Command:**

```bash
ast-grep --pattern 'function $NAME() { $$$ return $$$ }'  \
  --lang tsx src/components/
```
````

**Expected output:**

```
src/components/Button.tsx:5:export function Button() {
src/components/Card.tsx:10:export function Card() {
```

### Find TODOs

**Task:** Find all TODO comments

**Command:**

```bash
rg "TODO" --type js --type ts
```

**Expected output:**

```
src/utils.ts:42:// TODO: Add error handling
src/api.ts:15:// TODO: Implement retry logic
```

````

## Quality Self-Check Failures

Common failures and how to address them.

### "Can someone use this without follow-up questions?"

**If no:**

1. **Add more concrete examples:**
   ```markdown
   # Instead of:
   "Use the pattern for your use case"

   # Write:
   "For fetching URLs, use this pattern:
   ```python
   response = requests.get(url)
   ```"
````

2. **Explain jargon:**

   ```markdown
   # Instead of:

   "Use progressive disclosure"

   # Write:

   "Progressive disclosure: Show most important info first,
   details later. Example: Put common use cases before edge cases."
   ```

3. **Add decision trees:**

   ```markdown
   # Instead of:

   "Choose the right tool"

   # Write:

   "Need syntax-aware search? → ast-grep
   Need fast text search? → ripgrep"
   ```

### "Would this work in 6 months?"

**If no:**

1. **Isolate time-sensitive info:**

   ```markdown
   ## Current Best Practice (as of 2024)

   Use tool X for this task.

   ## Legacy Patterns

   Previously, tool Y was used...
   ```

2. **Remove absolute statements:**

   ```markdown
   # Instead of:

   "The new tool is way better!"

   # Write:

   "Tool X provides [specific benefit] over tool Y"
   ```

3. **Document version dependencies:**

   ```markdown
   ## Version Requirements

   This pattern requires:

   - Python 3.10+ (for match statement)
   - UV 0.1.0+ (for inline dependencies)
   ```

### "Are examples copy-pasteable and runnable?"

**If no:**

1. **Complete all placeholders:**

   ````markdown
   # Instead of:

   ```bash
   command <your-input>
   ```
   ````

   # Write:

   ```bash
   # Example with real values:
   ast-grep --pattern 'function $NAME() { $$$ }' src/

   # Customize by replacing:
   #   'src/' with your source directory
   #   'function' with 'class' for classes
   ```

   ```

   ```

2. **Add setup steps:**

   ````markdown
   ## Prerequisites

   ```bash
   # Install required tools
   brew install ast-grep

   # Verify installation
   which ast-grep
   ```
   ````

   ## Run Example

   ```bash
   ast-grep --pattern '...'
   ```

   ```

   ```

3. **Show expected output:**

   ````markdown
   ```bash
   ast-grep --pattern 'function $NAME() { $$$ }'
   ```
   ````

   **Expected output:**

   ```
   src/utils.ts:10:function formatDate() {
   src/api.ts:25:function fetchData() {
   ```

   **If you see:**

   - "pattern not found" → No matching functions
   - "file not found" → Check directory path

   ```

   ```

### "Can you find guidance in < 30 seconds?"

**If no:**

1. **Improve section headers:**

   ```markdown
   # Instead of:

   ## Part 1

   ## Part 2

   # Write:

   ## Finding Code by Structure (ast-grep)

   ## Finding Code by Text (ripgrep)
   ```

2. **Add table of contents:**

   ```markdown
   ## Quick Navigation

   - [When to Use](#when-to-use)
   - [Common Patterns](#common-patterns)
   - [Troubleshooting](#troubleshooting)
   - [Examples](#examples)
   ```

3. **Use progressive disclosure:**

   ```markdown
   ## Quick Reference

   Most common cases (80% of usage)

   ## Detailed Guidance

   Edge cases and advanced patterns

   ## Complete API Reference

   See [reference.md](./reference.md)
   ```

### "Are error messages helpful enough?"

**If no:**

1. **Add context to errors:**

   ```python
   # Instead of:
   raise ValueError("invalid input")

   # Write:
   raise ValueError(
       f"Invalid input: {input_value}\n"
       f"Expected: string or Path object\n"
       f"Got: {type(input_value)}\n"
       f"Hint: Convert to string first with str(input_value)"
   )
   ```

2. **Add error recovery steps:**

   ```markdown
   ## Troubleshooting

   ### Error: "pattern not found"

   **Cause:** No code matches your pattern

   **Solutions:**

   1. Check pattern syntax: `ast-grep --pattern 'your pattern' --debug`
   2. Try simpler pattern: Start with just function name
   3. Check file language: Use `--lang tsx` for TypeScript
   4. Verify directory: `ls src/` to confirm files exist
   ```

3. **Link common errors in skill:**

   ```markdown
   ## Common Errors

   - [Pattern not found](#error-pattern-not-found)
   - [Invalid syntax](#error-invalid-syntax)
   - [Permission denied](#error-permission-denied)

   For complete list, see [troubleshooting.md](./troubleshooting.md)
   ```

## Maintenance Issues

### Skill Becomes Outdated

**Problem:** Tool updates, skill doesn't reflect changes

**Fix:**

1. **Add changelog section:**

   ```markdown
   ## Changelog

   ### 2024-10 - UV 0.5.0 Update

   - Added `--script` flag requirement
   - Updated shebang format
   - See: https://docs.astral.sh/uv/...
   ```

2. **Version pin in examples:**

   ```markdown
   ## Note: UV Version

   These examples require UV 0.5.0+
   Check your version: `uv --version`
   ```

3. **Regular review schedule:**
   - Monthly: Check tool versions
   - Quarterly: Review examples
   - Annually: Major skill refresh

### Skill Conflicts with Other Skills

**Problem:** Multiple skills for similar topics, unclear which to use

**Fix:**

1. **Clarify boundaries:**

   ```markdown
   ## Scope

   This skill covers:

   - Standalone Python scripts
   - Single-file tools
   - UV-based dependency management

   This skill does NOT cover:

   - Python packages (see python-packaging skill)
   - Virtual environments (see python-env skill)
   - pip-based projects (see python-pip skill)
   ```

2. **Add navigation:**

   ```markdown
   ## Related Skills

   - For packages: python-packaging
   - For testing: python-testing
   - For async: python-async
   ```

3. **Merge if too similar:**
   - Combine overlapping skills
   - Update descriptions to avoid conflict
   - Archive deprecated skills
