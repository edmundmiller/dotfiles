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

## Quick Reference

### Core Principles

**Every skill must have:**

- ✅ Specific description with trigger keywords (< 100 chars)
- ✅ Under 500 lines (split into directory if longer)
- ✅ Concrete examples (not abstract)
- ✅ Consistent terminology
- ✅ Progressive disclosure (most important first)

**Red flags:**

- ❌ Vague description like "Help with Python"
- ❌ Single file over 500 lines
- ❌ Abstract guidance without examples
- ❌ Mixing terminology (e.g., "commit" and "change" without explanation)
- ❌ Time-sensitive info (e.g., "new tool just released")

### Quality Checklist

Before finalizing a skill:

- [ ] Description includes key trigger words
- [ ] SKILL.md is under 500 lines
- [ ] Examples are concrete and copy-pasteable
- [ ] Terminology is consistent
- [ ] File structure follows conventions (see below)
- [ ] Scripts solve problems (don't punt to Claude)
- [ ] Error handling is explicit with helpful messages
- [ ] No "voodoo constants" - all values justified
- [ ] Tested with Haiku, Sonnet, and Opus
- [ ] Real usage testing completed

## File Structure

**For skills under 500 lines:**

```
my-skill.md                # Single file
```

**For skills over 500 lines:**

```
my-skill/
├── SKILL.md              # Main instructions (< 500 lines)
├── examples.md           # Detailed examples
├── reference.md          # API/command reference (optional)
└── scripts/              # Helper scripts (optional)
    └── validate.py
```

**Key principles:**

- SKILL.md always under 500 lines
- Related files use UPPERCASE for visibility (FORMS.md, EXAMPLES.md)
- Scripts in subdirectory, executed not loaded as context
- Each file has single, clear purpose

**Example from real skill:**

```
pdf/
├── SKILL.md              # Core PDF guidance
├── FORMS.md              # Form-filling specific guidance
├── examples.md           # Extended examples
└── scripts/
    ├── analyze_form.py   # Utility script
    └── fill_form.py      # Form processor
```

## Core Quality Standards

### 1. Description Quality

**Format:** Frontmatter YAML at top of SKILL.md

```yaml
---
description: "Specific action + key terms + when to use"
priority: 5
---
```

**Requirements:**

- Include key terms that trigger the skill
- Explain both WHAT and WHEN
- Keep under 100 characters
- Use terms users naturally say

📖 See [examples.md](./examples.md#description-quality) for good/bad examples

### 2. Content Structure

**SKILL.md must be:**

- Under 500 lines total
- Well-organized with clear sections
- Using progressive disclosure
- Focused on one coherent topic

**If exceeding 500 lines:**

1. Split into directory structure
2. Keep core guidance in SKILL.md
3. Move detailed examples to examples.md
4. Move reference material to reference.md
5. Move scripts to scripts/ subdirectory

**Progressive disclosure pattern:**

```markdown
# Skill Name

Brief intro (1-2 sentences)

## When to Use

Quick bullet list

## Quick Reference

Most common cases with examples

## Detailed Guidance

(Or link to examples.md)

## Advanced Patterns

(Or link to patterns.md)
```

### 3. Terminology Consistency

**Rules:**

- Use consistent terms throughout all files
- Establish vocabulary early
- Explain synonyms when first used
- Don't mix related terms without explanation

📖 See [examples.md](./examples.md#terminology-consistency) for patterns

### 4. Concrete Examples

**Every pattern needs a real, runnable example.**

Examples must:

- Be copy-pasteable
- Show actual code/commands
- Include expected output
- Demonstrate the principle

📖 See [examples.md](./examples.md#concrete-examples) for good/bad examples

### 5. File Reference Depth

**Keep references one level deep:**

```markdown
See examples.md for detailed patterns # ✅ Good
```

```markdown
See examples.md which references patterns.md
which has code in scripts/ # ❌ Bad - too deep
```

### 6. Time-Sensitive Information

**Isolate or avoid time-sensitive content:**

```markdown
## Current Best Practice (as of 2024)

Use ast-grep for syntax-aware searches

## Legacy Patterns

Previously, ripgrep was used...
```

📖 See [examples.md](./examples.md#time-sensitive-information) for deprecation patterns

## Code and Script Quality

### Scripts Should Solve Problems

**Don't punt to Claude - solve the problem in the script:**

- ✅ Validate and return specific errors
- ✅ Handle edge cases explicitly
- ✅ Provide actionable error messages
- ❌ Leave TODOs for Claude to figure out
- ❌ Generic "check this" functions

### Error Handling

**Every error path needs helpful messages:**

```python
except FileNotFoundError:
    print("Error: jj not found. Install with: brew install jj")
    sys.exit(1)
```

### No Voodoo Constants

**Justify all magic numbers:**

```python
TIMEOUT_SECONDS = 30  # API requests take 5-10s, allow 3x buffer
```

### Package Verification

**List all dependencies with install instructions:**

```markdown
## Dependencies

Required:

- `ast-grep` - Install: `brew install ast-grep`

Verify: `which ast-grep`
```

📖 See [examples.md](./examples.md#code-and-script-quality) for detailed patterns

## Workflow Quality

### Clear Steps

**Use numbered steps with verification:**

````markdown
1. **Create directory:**
   ```bash
   mkdir my-dir
   ```
````

Verify: `ls my-dir`

2. **Create file:**
   ...

````

### Decision Trees

**Complex workflows need decision points:**

```markdown
**Need X?** → Use tool A
**Need Y?** → Use tool B
**Need both?** → Use A then B
````

📖 See [examples.md](./examples.md#workflow-quality) for patterns

## Testing

Every skill needs testing across:

- **Models**: Haiku, Sonnet, Opus
- **Scenarios**: Simple, edge case, complex
- **Real usage**: New project, no external help

📖 See [testing.md](./testing.md) for detailed testing guidelines

## Troubleshooting

Common issues:

- Skill not being invoked → Check description keywords
- Too broad → Split into focused skills
- Too abstract → Add concrete examples

📖 See [troubleshooting.md](./troubleshooting.md) for complete guide

## Quality Self-Check

Before considering a skill complete:

1. **Can someone use this without follow-up questions?**

   - If no: Add more concrete examples

2. **Would this work in 6 months?**

   - If no: Isolate time-sensitive info

3. **Are examples copy-pasteable and runnable?**

   - If no: Complete all examples

4. **Can you find guidance in < 30 seconds?**

   - If no: Improve structure and headers

5. **Are error messages helpful enough?**
   - If no: Add more context and hints

## Additional Resources

- [examples.md](./examples.md) - Detailed good/bad examples for all principles
- [testing.md](./testing.md) - Complete testing guidelines
- [troubleshooting.md](./troubleshooting.md) - Common issues and fixes
