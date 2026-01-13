---
name: ast-grep
description: >
  Structural code search and refactoring using AST patterns. Use when searching for code
  patterns (not text), finding deprecated patterns, or systematic refactoring. Supports
  Nextflow, JavaScript, Python, and more.
license: MIT
metadata:
  version: "1.0.0"
  author: "Edmund Miller"
---

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

## Quick Reference

| Task | Command |
|------|---------|
| Find pattern | `ast-grep run --pattern 'PATTERN' --lang LANG` |
| Scan with rule | `ast-grep scan --rule file.yaml` |
| Debug AST | `--debug-query=ast` |
| Test pattern match | `--debug-query=pattern` |
| Use inline rule | `--inline-rules 'YAML'` |
| Nextflow patterns | Use `_VAR` instead of `$VAR` |

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

## Integration Notes

### OpenCode Tools

This repository includes **nf-ast-grep MCP tools** for Nextflow-specific searches:
- `nf-ast-grep_find_processes` - Find all process definitions
- `nf-ast-grep_find_workflows` - Find workflow definitions
- `nf-ast-grep_find_channels` - Find channel factory operations
- `nf-ast-grep_find_deprecated` - Find deprecated patterns
- `nf-ast-grep_lint` - Run lint rules on Nextflow code
- `nf-ast-grep_search` - Search with custom patterns

Use these tools for Nextflow work instead of raw ast-grep commands when available.

### Shell Execution

When running ast-grep from bash:
- **Single quotes** preserve `$` metavariables: `ast-grep run --pattern 'console.$METHOD'`
- **Escape in double quotes**: `ast-grep run --pattern "console.\$METHOD"`
- For complex patterns, use `--inline-rules` with a heredoc or rule files

### When to Delegate

- **Large searches**: Use explore agents for searching across large codebases
- **Simple patterns**: Run ast-grep directly for quick one-off searches
- **Rule development**: Use iterative bash commands with `--debug-query`

## Error Handling

### "Pattern not matching expected code"

**Cause**: Pattern syntax doesn't match AST structure.

**Solution**:
1. Inspect actual AST: `ast-grep run --pattern '$$$' --debug-query=ast file.ext`
2. Check node kinds match what you expect
3. Simplify pattern and add constraints incrementally

### "ast-grep: command not found"

**Cause**: ast-grep not installed or not in PATH.

**Solution**:
```bash
# Install via cargo
cargo install ast-grep

# Or via npm
npm install -g @ast-grep/cli

# Or via nix
nix shell nixpkgs#ast-grep
```

### "Language not supported"

**Cause**: Trying to use an unsupported or unconfigured language.

**Solution**:
- Check supported languages: `ast-grep --help`
- For custom languages (like Nextflow), ensure `sgconfig.yml` is present with `customLanguages` configured
- See [Nextflow Reference](references/nextflow.md) for custom language setup

### "Missing stopBy in relational rule"

**Cause**: Relational rules (`inside`, `has`, `precedes`, `follows`) default to `stopBy: neighbor` which only checks immediate children.

**Solution**: Always add `stopBy: end` to search the full subtree:
```yaml
rule:
  has:
    pattern: target_pattern
    stopBy: end  # Don't forget this!
```

### "Metavariable not captured"

**Cause**: Using `_` prefix makes metavariables non-capturing, or metavariable used before it's defined.

**Solution**:
- Use `$VAR` (or `_VAR` in Nextflow) for capturing
- In `all` blocks, define metavariables before using them (rules process in order)

### Shell escaping issues

**Cause**: `$` in patterns gets interpreted as shell variable.

**Solution**:
```bash
# Use single quotes (preferred)
ast-grep run --pattern 'console.$METHOD'

# Or escape in double quotes
ast-grep run --pattern "console.\$METHOD"

# Or use rule files to avoid shell entirely
ast-grep scan --rule my-rule.yaml
```

### "Rule file not found" or YAML errors

**Cause**: Invalid YAML syntax or wrong file path.

**Solution**:
1. Validate YAML syntax (check indentation, colons, quotes)
2. Use absolute paths or run from correct directory
3. Test with `--inline-rules` first before creating rule file

## Examples

### Example 1: Finding and Fixing Deprecated Nextflow Patterns

**User request**: "Find all uses of the deprecated Channel.from() in our Nextflow pipeline"

**Workflow**:

```bash
# Step 1: Quick search to see scope of problem
ast-grep run --pattern 'Channel.from(___)' --lang nextflow

# Step 2: If many results, use the lint tool for structured output
# (uses existing deprecated-channel-from.yaml rule)
```

**Rule used** (`deprecated-channel-from.yaml`):
```yaml
id: deprecated-channel-from
language: nextflow
severity: warning
message: "Channel.from() is deprecated in DSL2"
note: |
  Use Channel.of() for simple values or Channel.fromList() for lists.
  
  Before: Channel.from(1, 2, 3)
  After:  Channel.of(1, 2, 3)
rule:
  pattern: Channel.from(___)
```

**Result**: Found 3 instances in `main.nf`, updated to use `Channel.of()`.

---

### Example 2: Refactoring Console Logging Across a Codebase

**User request**: "Replace all console.log calls with our custom logger"

**Workflow**:

```bash
# Step 1: Find all console.log calls
ast-grep run --pattern 'console.log($$$ARGS)' --lang js

# Step 2: Create a rewrite rule
cat > /tmp/replace-console.yaml << 'EOF'
id: replace-console-log
language: javascript
rule:
  pattern: console.log($$$ARGS)
fix: logger.info($$$ARGS)
EOF

# Step 3: Preview changes
ast-grep scan --rule /tmp/replace-console.yaml

# Step 4: Apply changes (with --update-all)
ast-grep scan --rule /tmp/replace-console.yaml --update-all
```

**Key insight**: The `fix` field in rules enables automatic refactoring, not just finding.

---

### Example 3: Creating a Custom Linting Rule from Scratch

**User request**: "Create a rule that warns when async functions don't have error handling"

**Workflow**:

```bash
# Step 1: Create example code to understand the AST
cat > /tmp/example.js << 'EOF'
async function good() {
  try {
    await fetch('/api');
  } catch (e) {
    console.error(e);
  }
}

async function bad() {
  await fetch('/api');  // No try-catch!
}
EOF

# Step 2: Inspect AST structure
ast-grep run --pattern '$$$' --debug-query=ast /tmp/example.js

# Step 3: Write initial pattern for async functions with await
ast-grep run --pattern 'async function $NAME($$$) { $$$ }' /tmp/example.js

# Step 4: Add constraint: must have await but no try statement
cat > /tmp/async-error-handling.yaml << 'EOF'
id: async-needs-error-handling
language: javascript
severity: warning
message: "Async function '$NAME' has await but no try-catch"
note: |
  Async functions with await should have error handling.
  Wrap await calls in try-catch blocks.
rule:
  all:
    - pattern: async function $NAME($$$PARAMS) { $$$BODY }
    - has:
        pattern: await $$$
        stopBy: end
    - not:
        has:
          kind: try_statement
          stopBy: end
EOF

# Step 5: Test the rule
ast-grep scan --rule /tmp/async-error-handling.yaml /tmp/example.js
```

**Result**: Rule correctly flags `bad()` but not `good()`.

---

### Example 4: Finding Implicit Closure Parameters in Nextflow

**User request**: "Find closures that use implicit 'it' parameter - we want explicit parameters for readability"

**Workflow**:

```bash
# Use the existing rule via nf-ast-grep tools
# Or run directly:
ast-grep scan --rule config/opencode/skills/ast-grep/rules/implicit-it-closure.yaml
```

**Rule explanation** (`implicit-it-closure.yaml`):
```yaml
id: implicit-it-closure
language: nextflow
severity: hint
message: "Consider using explicit closure parameter instead of implicit 'it'"
rule:
  all:
    - kind: closure
    - has:
        pattern: it
        stopBy: end
    - not:
        has:
          kind: closure_parameter
          stopBy: end
```

This uses `kind` matching (AST node type) combined with `has`/`not has` to find closures that reference `it` but don't declare a parameter.

---

### Example 5: Multi-Pattern Search with Dependencies

**User request**: "Find all React components that use useState but don't have a useEffect cleanup"

**Workflow**:

```bash
cat > /tmp/missing-cleanup.yaml << 'EOF'
id: missing-useeffect-cleanup
language: typescript
severity: warning
message: "Component uses useState but may be missing useEffect cleanup"
rule:
  all:
    - kind: function_declaration
    - has:
        pattern: useState($$$)
        stopBy: end
    - has:
        pattern: useEffect($$$)
        stopBy: end
    - not:
        has:
          pattern: |
            useEffect(() => {
              $$$SETUP
              return $$$CLEANUP
            }, $$$DEPS)
          stopBy: end
EOF

ast-grep scan --rule /tmp/missing-cleanup.yaml src/
```

**Key insight**: Complex patterns can combine multiple `has` and `not has` clauses to express sophisticated constraints.

## References

For detailed syntax and advanced features, see:
- [Rule Reference](references/rule-reference.md) - Complete rule syntax documentation
- [Nextflow Reference](references/nextflow.md) - Nextflow-specific patterns and examples

---

## Progressive Disclosure

This skill document provides a practical introduction to ast-grep. For deeper understanding:

1. **Start here** - Quick reference and common patterns cover 80% of use cases
2. **Rule Reference** - When you need advanced rule syntax (relational rules, transformations)
3. **Nextflow Reference** - For Nextflow-specific work (custom language config, real examples)
4. **ast-grep docs** - For edge cases: https://ast-grep.github.io/
