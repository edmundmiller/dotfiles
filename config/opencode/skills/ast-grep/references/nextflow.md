# Nextflow ast-grep Reference

Nextflow-specific patterns and configuration for ast-grep.

## Configuration

Nextflow support requires a custom tree-sitter parser. The configuration in `config/opencode/ast-grep/sgconfig.yml`:

```yaml
customLanguages:
  nextflow:
    libraryPath:
      aarch64-apple-darwin: lib/macos-arm64/libnextflow.dylib
      x86_64-unknown-linux-gnu: lib/linux-x64/libnextflow.so
    extensions: [nf, config]
    expandoChar: _  # Use _VAR instead of $VAR
```

**Important:** Because Nextflow uses `$` for string interpolation (`$variable`, `${expression}`), ast-grep patterns use `_` as the metavariable prefix instead:

| Standard | Nextflow |
|----------|----------|
| `$VAR` | `_VAR` |
| `$$VAR` | `__VAR` |
| `$$$VAR` | `___VAR` |

## Quick Commands

```bash
# Search Nextflow files
ast-grep run --pattern 'Channel.from(___)' --lang nextflow

# Scan with rules
ast-grep scan --rule config/opencode/ast-grep/rules/

# Debug AST structure
ast-grep run --pattern '___' --debug-query=ast workflow.nf
```

## OpenCode MCP Tools

OpenCode provides MCP tools for Nextflow ast-grep operations:

| Tool | Purpose |
|------|---------|
| `nf-ast-grep_find_processes` | Find all process definitions |
| `nf-ast-grep_find_workflows` | Find workflow definitions |
| `nf-ast-grep_find_channels` | Find channel factory operations |
| `nf-ast-grep_find_deprecated` | Find deprecated patterns |
| `nf-ast-grep_lint` | Run all lint rules |
| `nf-ast-grep_search` | Custom pattern search |

---

## Common Patterns

### Channel Operations

```yaml
# Find Channel.from() (deprecated)
rule:
  pattern: Channel.from(___)

# Find Channel.of()
rule:
  pattern: Channel.of(___)

# Find fromFilePairs
rule:
  pattern: Channel.fromFilePairs(___)

# Find .set{} operator (deprecated)
rule:
  pattern: .set { ___ }
```

### Process Definitions

```yaml
# Find process definitions
rule:
  kind: process_definition

# Find process with specific directive
rule:
  all:
    - kind: process_definition
    - has:
        pattern: container _CONTAINER
        stopBy: end

# Find process input declarations
rule:
  all:
    - kind: input_block
    - inside:
        kind: process_definition
        stopBy: end
```

### Workflow Definitions

```yaml
# Find workflow definitions
rule:
  kind: workflow_definition

# Find main entry workflow (unnamed)
rule:
  all:
    - kind: workflow_definition
    - not:
        has:
          kind: workflow_name
```

### Closures and Operators

```yaml
# Find map operations
rule:
  pattern: .map { ___ }

# Find filter operations
rule:
  pattern: .filter { ___ }

# Find closures using implicit 'it'
rule:
  all:
    - kind: closure
    - has:
        pattern: it
    - not:
        has:
          kind: closure_parameter
```

---

## Example Rules

### Deprecated Channel.from()

```yaml
id: deprecated-channel-from
language: nextflow
severity: warning
message: "Channel.from() is deprecated. Use Channel.of() or Channel.fromList() instead."
note: |
  Channel.from() was deprecated in Nextflow DSL2.
  - Use Channel.of() for individual items: Channel.of(1, 2, 3)
  - Use Channel.fromList() for lists: Channel.fromList([1, 2, 3])
rule:
  pattern: Channel.from(___)
```

### Hardcoded Paths

```yaml
id: hardcoded-paths
language: nextflow
severity: warning
message: "Avoid hardcoded absolute paths. Use params, projectDir, or launchDir instead."
note: |
  Hardcoded paths reduce portability. Use:
  - params.input for user-configurable paths
  - projectDir for paths relative to the pipeline
  - launchDir for paths relative to where pipeline was launched
  - workDir for work directory paths
rule:
  regex: '"/(?:home|usr|opt|data|scratch|tmp)/[^"]*"'
```

### Deprecated .set{} Operator

```yaml
id: deprecated-set-operator
language: nextflow
severity: warning
message: "The .set{} operator is deprecated in DSL2. Use variable assignment or emit: block."
note: |
  In DSL2, instead of:
    channel.set { my_channel }
  Use direct assignment:
    my_channel = channel
  Or in workflows, use the emit: block for outputs.
rule:
  pattern: .set { ___ }
```

### Implicit 'it' in Closures

```yaml
id: implicit-it-closure
language: nextflow
severity: hint
message: "Consider using explicit closure parameters instead of implicit 'it' for clarity."
note: |
  While 'it' works as an implicit parameter, explicit parameters improve readability:

  Instead of:
    channel.map { it.name }

  Consider:
    channel.map { file -> file.name }

  This makes the code more self-documenting.
rule:
  all:
    - kind: closure
    - has:
        pattern: it
    - not:
        has:
          kind: closure_parameter
```

### Channel.value() for Reusable Values

```yaml
id: channel-value-in-process
language: nextflow
severity: hint
message: "Consider using Channel.value() for single-value channels to allow process reuse."
note: |
  When passing a single value that should be reused across multiple process invocations,
  wrap it in Channel.value() to create a value channel that can be consumed multiple times.

  Example:
    reference = Channel.value(params.reference)
    PROCESS(samples, reference)  // reference reused for each sample
rule:
  all:
    - kind: channel_value
    - inside:
        kind: workflow_definition
```

---

## AST Node Types

Common Nextflow AST node kinds for pattern matching:

| Node Kind | Description |
|-----------|-------------|
| `process_definition` | Process block |
| `workflow_definition` | Workflow block |
| `input_block` | Process input: section |
| `output_block` | Process output: section |
| `script_block` | Process script: section |
| `closure` | Closure `{ ... }` |
| `closure_parameter` | Explicit closure param `{ x -> }` |
| `channel_value` | Channel.value() call |
| `method_call` | Method invocation |

Use `--debug-query=ast` to discover more node types:

```bash
ast-grep run --pattern '___' --debug-query=ast your_file.nf
```
