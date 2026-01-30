# Skill Testing Guidelines

Complete testing guidelines for validating Claude Code skills. Referenced from SKILL.md.

## Contents

- [Overview](#overview) - Three dimensions of testing
- [Create Evaluation Scenarios](#create-evaluation-scenarios) - Test case templates
- [Model Testing](#model-testing) - Testing across Haiku, Sonnet, and Opus
  - [Haiku (Fast, Basic Reasoning)](#haiku-fast-basic-reasoning)
  - [Sonnet (Balanced)](#sonnet-balanced)
  - [Opus (Complex Reasoning)](#opus-complex-reasoning)
- [Real Usage Testing](#real-usage-testing) - Actual workflow testing
- [Testing Checklist](#testing-checklist) - Complete verification checklist
- [Continuous Testing](#continuous-testing) - Ongoing improvement
- [Testing Anti-Patterns](#testing-anti-patterns) - What to avoid

## Overview

Every skill must be tested across three dimensions:

1. **Models** - Haiku, Sonnet, Opus
2. **Scenarios** - Simple, edge case, complex
3. **Real usage** - Actual workflows without external help

## Create Evaluation Scenarios

Every skill needs at least 3 test cases covering different complexity levels.

### Test Case Template

```markdown
## Skill Evaluation Scenarios

Test this skill with:

1. **Simple case:** [Common user request]
   - **Input**: User asks "[specific request]"
   - **Expected**: Skill [expected behavior]
   - **Verify**: [How to check success]

2. **Edge case:** [Unusual but valid request]
   - **Input**: User asks "[edge case request]"
   - **Expected**: Skill [expected behavior]
   - **Verify**: [How to check success]

3. **Complex case:** [Advanced scenario]
   - **Input**: User asks "[complex request]"
   - **Expected**: Skill [expected behavior]
   - **Verify**: [How to check success]
```

### Example: Python Scripts Skill

```markdown
## Skill Evaluation Scenarios

Test this skill with:

1. **Simple case:** User asks "create a Python script"
   - **Input**: "Create a Python script to fetch a URL"
   - **Expected**: Skill provides UV shebang template with requests dependency
   - **Verify**:
     - Template includes `#!/usr/bin/env -S uv run --script`
     - Dependencies section lists "requests"
     - Script is executable and runs

2. **Edge case:** User asks "script without dependencies"
   - **Input**: "Create a Python script using only stdlib"
   - **Expected**: Skill provides minimal UV shebang without dependencies
   - **Verify**:
     - Template includes shebang
     - No dependencies array OR empty dependencies array
     - Script uses only stdlib imports

3. **Complex case:** User asks "async script with multiple dependencies"
   - **Input**: "Create async script that fetches multiple URLs concurrently"
   - **Expected**: Skill provides UV shebang with httpx and asyncio
   - **Verify**:
     - Dependencies include async-compatible library (httpx, aiohttp)
     - Code uses async/await correctly
     - Script demonstrates concurrent fetching
```

## Model Testing

Test your skill with all three Claude models to ensure consistent behavior.

### Haiku (Fast, Basic Reasoning)

**Focus:** Simple, common scenarios

**Test for:**

- ✅ Skill is correctly invoked
- ✅ Basic guidance is followed
- ✅ Response quality is acceptable
- ✅ Examples are used appropriately

**Common issues:**

- Skill not invoked (description lacks keywords)
- Oversimplified responses (missing detail)
- Doesn't follow complex instructions

**Test procedure:**

```markdown
1. Set model to Haiku
2. Ask simple case question
3. Verify skill is invoked
4. Check response follows skill guidance
5. Verify examples are copy-pasteable
```

**Example test:**

```
User: "Create a Python script to read a file"
Haiku: Should invoke python-scripts skill and provide UV shebang
Verify: Check shebang format, dependencies (if any), runnable code
```

### Sonnet (Balanced)

**Focus:** Moderate complexity scenarios

**Test for:**

- ✅ Detailed guidance is followed
- ✅ Examples are used correctly
- ✅ Edge cases are handled
- ✅ Response shows understanding of context

**Common issues:**

- Skips verification steps
- Doesn't use decision trees
- Misses subtleties in guidance

**Test procedure:**

```markdown
1. Set model to Sonnet
2. Ask moderate complexity question
3. Verify skill is invoked
4. Check response follows detailed guidance
5. Verify decision trees are used correctly
6. Check verification steps are included
```

**Example test:**

```
User: "Create a Python script that handles errors gracefully"
Sonnet: Should invoke python-scripts skill and include try/except with helpful messages
Verify: Error handling exists, messages are actionable, follows skill patterns
```

### Opus (Complex Reasoning)

**Focus:** Edge cases and complex scenarios

**Test for:**

- ✅ Advanced guidance is applied
- ✅ Creative solutions are appropriate
- ✅ Edge cases are handled correctly
- ✅ Explanations are thorough

**Common issues:**

- Over-complicates simple tasks
- Adds unnecessary abstractions
- Deviates from skill guidance

**Test procedure:**

```markdown
1. Set model to Opus
2. Ask complex/edge case question
3. Verify skill is invoked
4. Check response applies advanced patterns
5. Verify creativity stays within skill bounds
6. Check explanations are clear and justified
```

**Example test:**

```
User: "Create a Python script with multiple commands and shared options"
Opus: Should invoke python-scripts skill and provide typer-based CLI
Verify: Uses Typer correctly, shared options implemented, follows UV shebang pattern
```

## Real Usage Testing

Test the skill in actual workflows without external help.

### Test Procedure

1. **Fresh start test:**
   - Start a new project
   - Use only the skill guidance (no external docs)
   - Complete a real task
   - Note any gaps or unclear instructions

2. **Colleague test:**
   - Ask a colleague to use the skill
   - Don't explain anything beforehand
   - Observe where they get stuck
   - Fix unclear sections

3. **Different project test:**
   - Try the skill in a different codebase
   - Verify guidance is project-agnostic
   - Check examples work in new context
   - Update if project-specific assumptions found

4. **Error path test:**
   - Intentionally trigger failure scenarios
   - Verify error messages are helpful
   - Check recovery steps are clear
   - Add missing error handling guidance

### Example: Testing Python Scripts Skill

```markdown
## Real Usage Test Log

**Test 1: Fresh start**

- Task: Create CLI tool for processing CSV files
- Result: ✅ Successfully created using only skill guidance
- Issues found:
  - Unclear how to add multiple dependencies
  - Missing example for file I/O
- Fixes: Added multi-dependency example, added file operations section

**Test 2: Colleague test**

- Tester: Junior developer, unfamiliar with UV
- Task: Create script to fetch GitHub issues
- Result: ⚠️ Got stuck on UV installation
- Issues found:
  - No UV installation instructions
  - Unclear if UV is required or optional
- Fixes: Added UV installation section, clarified requirements

**Test 3: Different project**

- Project: Internal automation tools
- Task: Create script to sync databases
- Result: ✅ Worked with minor adjustments
- Issues found:
  - Example used public APIs (company uses internal)
  - Pattern assumed single-file scripts (needed package structure)
- Fixes: Made examples more generic, added note about multi-file projects

**Test 4: Error paths**

- Scenario: Wrong shebang format
- Result: ❌ Error message not helpful
- Issues found:
  - UV error: "invalid script" (cryptic)
  - Skill didn't explain common shebang errors
- Fixes: Added troubleshooting section for shebang errors
```

## Testing Checklist

Before finalizing a skill, verify:

### Description and Invocation

- [ ] Skill is invoked with simple trigger phrase
- [ ] Skill is invoked with technical term
- [ ] Skill is NOT invoked for unrelated queries
- [ ] Priority is set appropriately (not too high/low)

### Content Quality

- [ ] All examples are copy-pasteable
- [ ] Examples work on first try
- [ ] Terminology is consistent across all examples
- [ ] File references are one level deep
- [ ] No time-sensitive information (or properly isolated)

### Code and Scripts

- [ ] Scripts have helpful error messages
- [ ] Scripts handle edge cases
- [ ] All constants are justified
- [ ] Dependencies are listed and verified
- [ ] Paths use forward slashes

### Model Testing

- [ ] Tested with Haiku (simple case works)
- [ ] Tested with Sonnet (moderate case works)
- [ ] Tested with Opus (complex case works)
- [ ] Responses consistent across models
- [ ] Skill guidance is followed in all cases

### Real Usage

- [ ] Fresh start test completed
- [ ] Colleague test completed
- [ ] Different project test completed
- [ ] Error path test completed
- [ ] All issues found have been fixed

### Documentation

- [ ] README explains when to use skill
- [ ] Examples show common use cases
- [ ] Troubleshooting section exists
- [ ] Links to related skills/docs

## Continuous Testing

After initial testing:

1. **Monitor usage:**
   - Track when skill is invoked
   - Note if invocation matches intent
   - Identify missing trigger words

2. **Collect feedback:**
   - Ask users if skill was helpful
   - Note common questions after using skill
   - Track modifications users make to examples

3. **Update regularly:**
   - Add newly discovered patterns
   - Update examples based on feedback
   - Remove outdated information
   - Clarify confusing sections

## Testing Anti-Patterns

**❌ Don't:**

- Test only simple cases
- Skip model comparison
- Test only in original project
- Ignore error scenarios
- Test once and never again

**✅ Do:**

- Test full range of complexity
- Compare all models
- Test in fresh environments
- Intentionally break things
- Re-test after updates
