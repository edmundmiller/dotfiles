# ast-grep Rule Reference

Complete reference for ast-grep rule syntax. For quick start, see [SKILL.md](../SKILL.md).

## Rule Categories

ast-grep rules fall into three categories:

| Category | Purpose | Examples |
|----------|---------|----------|
| **Atomic** | Match single AST properties | `pattern`, `kind`, `regex` |
| **Relational** | Match by relationship to other nodes | `inside`, `has`, `precedes`, `follows` |
| **Composite** | Combine multiple rules | `all`, `any`, `not`, `matches` |

---

## Atomic Rules

### pattern

Match code by its syntactic structure using a code snippet.

```yaml
rule:
  pattern: console.log($MSG)
```

**Pattern Object** (advanced):

```yaml
rule:
  pattern:
    context: 'class A { $METHOD() {} }'  # Provide syntactic context
    selector: method_definition           # Select specific node from context
    strictness: relaxed                   # relaxed, signature, smart (default), strict
```

### kind

Match nodes by their AST node type.

```yaml
rule:
  kind: function_declaration
```

Find node kinds using `--debug-query=ast`:
```bash
ast-grep run --pattern '$$$' --debug-query=ast file.js
```

### regex

Match node text against a regular expression.

```yaml
rule:
  regex: '^test_.*'  # Functions starting with test_
```

**Combine with kind for precision:**
```yaml
rule:
  all:
    - kind: identifier
    - regex: '^_'  # Private by convention
```

### nthChild

Match nodes by position among siblings.

```yaml
rule:
  nthChild: 1        # First child (1-indexed)
  # nthChild:
  #   position: 2
  #   reverse: true  # 2nd from last
  #   ofRule:        # Only count nodes matching this rule
  #     kind: argument
```

### range

Match nodes at specific source locations.

```yaml
rule:
  range:
    start: { line: 10, column: 0 }
    end: { line: 20, column: 0 }
```

---

## Relational Rules

Relational rules match nodes based on their relationship to other nodes.

**Critical:** Always use `stopBy: end` to search the full subtree.

### inside

Match nodes that are inside a parent matching a rule.

```yaml
rule:
  all:
    - pattern: $VAR
    - inside:
        kind: function_declaration
        stopBy: end
```

### has

Match nodes that contain a descendant matching a rule.

```yaml
rule:
  all:
    - kind: function_declaration
    - has:
        pattern: console.log($$$)
        stopBy: end
```

### precedes / follows

Match nodes that come before/after a sibling.

```yaml
rule:
  all:
    - pattern: import $$$
    - precedes:
        kind: function_declaration
        stopBy: end
```

### stopBy Options

| Value | Behavior |
|-------|----------|
| `neighbor` | (default) Stop at first sibling - rarely what you want |
| `end` | Search to end of subtree - **use this** |
| `{ rule }` | Stop when encountering node matching rule |

### field

Constrain matches to specific AST field names.

```yaml
rule:
  all:
    - pattern: $EXPR
    - inside:
        kind: call_expression
        field: arguments  # Only match if $EXPR is in arguments field
```

---

## Composite Rules

### all

Match when ALL sub-rules match. **Rules are evaluated in order** - use this when metavariables depend on each other.

```yaml
rule:
  all:
    - pattern: $FUNC($$$ARGS)    # First: capture $FUNC
    - has:
        pattern: $FUNC           # Then: use $FUNC in nested rule
        stopBy: end
```

### any

Match when ANY sub-rule matches.

```yaml
rule:
  any:
    - pattern: console.log($$$)
    - pattern: console.warn($$$)
    - pattern: console.error($$$)
```

### not

Negate a rule - match when sub-rule does NOT match.

```yaml
rule:
  all:
    - kind: function_declaration
    - not:
        has:
          pattern: return $$$
          stopBy: end
```

### matches

Reference another rule by ID (for reusable rules).

```yaml
rule:
  matches: other-rule-id

# In utils section:
utils:
  other-rule-id:
    pattern: some_pattern
```

---

## Metavariables

| Syntax | Description | Example Match |
|--------|-------------|---------------|
| `$VAR` | Single named node | `log` in `console.log` |
| `$$VAR` | Single node (named or anonymous) | `+` operator |
| `$$$VAR` | Zero or more nodes | `a, b, c` in `func(a, b, c)` |
| `$_` | Wildcard (non-capturing) | Any single node |
| `$$$` | Multi-wildcard (non-capturing) | Any sequence |

**Nextflow note:** Use `_` prefix instead of `$` (e.g., `_VAR` not `$VAR`) due to `expandoChar` configuration.

---

## Rule File Structure

```yaml
id: rule-id                    # Required: unique identifier
language: javascript           # Required: target language
severity: warning              # error, warning, hint, off
message: "Short description"   # Shown in output
note: |                        # Multi-line explanation
  Detailed explanation of why this is a problem
  and how to fix it.

rule:                          # The actual matching rule
  pattern: problematic_code

fix: replacement_code          # Optional: auto-fix template

utils:                         # Optional: reusable sub-rules
  helper-rule:
    pattern: helper_pattern
```

---

## Fix Templates

Use metavariables captured in the rule:

```yaml
rule:
  pattern: console.log($MSG)
fix: logger.info($MSG)
```

**Transformations:**

```yaml
fix: logger.info($MSG)
transform:
  NEW_MSG:
    substring:
      source: $MSG
      startChar: 1
      endChar: -1
```

Available transforms: `replace`, `substring`, `convert` (case conversion), `rewrite`.

---

## Debugging

```bash
# View AST structure
ast-grep run --pattern '$$$' --debug-query=ast file.js

# View CST (includes anonymous nodes)
ast-grep run --pattern '$$$' --debug-query=cst file.js

# Debug pattern matching
ast-grep run --pattern 'your_pattern' --debug-query=pattern file.js

# Test inline rule
ast-grep scan --inline-rules '
id: test
language: javascript
rule:
  pattern: console.log($$$)
' path/to/search
```
