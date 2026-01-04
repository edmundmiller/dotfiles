# ast-grep Skill

ast-grep is a structural code search and rewriting tool. Use it when you need to find or modify code based on its AST structure rather than text patterns.

## When to Use ast-grep

**Use ast-grep when:**
- Searching for code patterns (function calls, imports, specific constructs)
- Refactoring code systematically
- Finding deprecated patterns or anti-patterns
- The pattern involves code structure, not just text

**Use grep/ripgrep when:**
- Searching for literal strings, comments, or documentation
- Simple text matching is sufficient

## Quick Start

### Simple Pattern Search

```bash
# Find all console.log calls
ast-grep run --pattern 'console.log($$$ARGS)' --lang js

# Find Channel.from() calls in Nextflow
ast-grep run --pattern 'Channel.from(___)' --lang nextflow
```

### Using Rules for Complex Patterns

```bash
# Scan with a rule file
ast-grep scan --rule path/to/rule.yaml

# Quick inline rule test
ast-grep scan --inline-rules '
id: test-rule
language: javascript
rule:
  pattern: console.log($$$ARGS)
'
```

### Debugging Patterns

```bash
# See AST structure of code
ast-grep run --pattern '$$$' --debug-query=ast path/to/file.js

# See how pattern matches
ast-grep run --pattern 'your_pattern' --debug-query=pattern path/to/file.js
```

## Core Concepts

### Metavariables

| Syntax | Matches | Example |
|--------|---------|---------|
| `$VAR` | Single named node | `console.$METHOD` matches `console.log` |
| `$$VAR` | Single node (including anonymous) | `$$OP` matches operators |
| `$$$VAR` | Zero or more nodes | `func($$$ARGS)` matches any args |
| `_` prefix | Non-capturing (Nextflow) | `_VAR` instead of `$VAR` |

**Note:** In Nextflow, use `_` instead of `$` for metavariables (configured via `expandoChar` in sgconfig.yml).

### Rule Structure

```yaml
id: rule-name
language: javascript  # or nextflow, python, etc.
severity: warning     # error, warning, hint, off
message: "Human-readable message"
note: |
  Additional context and fix suggestions
rule:
  pattern: code_pattern_here
```

## Workflow for Writing Rules

1. **Understand the query** - What code pattern are you looking for?
2. **Create example code** - Write a small file with the pattern
3. **Inspect the AST** - Use `--debug-query=ast` to see structure
4. **Write initial pattern** - Start simple, use metavariables
5. **Test and refine** - Use `--debug-query=pattern` to debug matches
6. **Add constraints** - Use relational rules (`inside`, `has`) as needed

## Common Patterns

### Match function with specific content

```yaml
rule:
  all:
    - pattern: function $NAME($$$PARAMS) { $$$ }
    - has:
        pattern: console.log($$$)
        stopBy: end
```

### Match code inside a context

```yaml
rule:
  all:
    - pattern: await $PROMISE
    - inside:
        kind: try_statement
        stopBy: end
```

### Match missing pattern (lint for absence)

```yaml
rule:
  all:
    - pattern: function $NAME($$$) { $$$ }
    - not:
        has:
          pattern: return $$$
          stopBy: end
```

## Key Principles

1. **Always use `stopBy: end`** for relational rules (`inside`, `has`, `precedes`, `follows`) to search the full subtree
2. **Start simple** - Get a basic pattern working before adding complexity
3. **Escape `$` in shell** - Use `\$VAR` or single quotes when running from bash
4. **Use `all` for order** - When metavariables depend on each other, `all` processes rules in order

## References

For detailed syntax and advanced features, see:
- [Rule Reference](references/rule-reference.md) - Complete rule syntax documentation
- [Nextflow Reference](references/nextflow.md) - Nextflow-specific patterns and examples
