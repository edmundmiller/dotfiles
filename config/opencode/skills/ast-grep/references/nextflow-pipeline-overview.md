---
name: nextflow-pipeline-overview
description: Efficiently understand unfamiliar Nextflow pipelines without reading all files. Use when encountering a new pipeline or needing to explain pipeline structure.
---

# Nextflow Pipeline Overview Skill

## When to Use This Skill

Use this skill when:

- Encountering an unfamiliar Nextflow pipeline for the first time
- Asked to explain what a pipeline does
- Needing to understand pipeline structure before making changes
- Investigating pipeline organization or complexity
- Preparing to debug or extend a Nextflow workflow

## Available Tools

You have access to these specialized pipeline overview tools:

### `nf-workflow-overview_overview`

Get a comprehensive overview including structure summary, workflows, processes count, and key parameters.

```
nf-workflow-overview_overview(directory?: string)
```

### `nf-workflow-overview_tree`

Show directory tree of pipeline components (modules, subworkflows, workflows).

```
nf-workflow-overview_tree(directory?: string, depth?: string)
```

### `nf-workflow-overview_includes`

Extract include statements showing dependencies between modules/subworkflows/workflows.

```
nf-workflow-overview_includes(directory?: string, file?: string)
```

### `nf-workflow-overview_config_params`

Extract params block from nextflow.config with schema information.

```
nf-workflow-overview_config_params(directory?: string)
```

### `nf-workflow-overview_component_count`

Quick count of processes, workflows, modules (local vs nf-core).

```
nf-workflow-overview_component_count(directory?: string)
```

## Recommended Workflow

### For New Pipelines

1. Start with `overview` to get high-level structure
2. Use `tree` to see directory organization
3. Check `config_params` to understand available parameters
4. Use `includes` to map dependency graph

### For Large Pipelines

1. Use `component_count` first for quick complexity gauge
2. Follow with `overview` for structure summary
3. Use `includes` to understand modular organization
4. Read specific files identified as critical

### For Debugging

1. Run `overview` to refresh on pipeline structure
2. Use `includes` to trace which modules are involved
3. Check `config_params` if issue is parameter-related

## Key Principles

**Progressive Disclosure**: Start broad (overview), then drill down (specific files)

**Token Efficiency**: These tools extract only essential information, avoiding reading entire pipeline files

**Context Building**: Use multiple tools in sequence to build mental model before diving into code

**ast-grep Integration**: Tools use ast-grep for syntax-aware analysis when available

## Example Usage

```typescript
// When user asks: "What does this nf-core/rnaseq pipeline do?"
(await nf) - workflow - overview_overview({ directory: "/path/to/nf-core-rnaseq" });
(await nf) - workflow - overview_tree({ directory: "/path/to/nf-core-rnaseq", depth: "2" });

// When user asks: "How many processes does this pipeline have?"
(await nf) - workflow - overview_component_count({ directory: "/path/to/pipeline" });

// When user asks: "What parameters can I configure?"
(await nf) - workflow - overview_config_params({ directory: "/path/to/pipeline" });
```

## Integration with Other Skills

This skill complements:

- **nf-ast-grep tools**: For finding specific code patterns
- **nextflow-dev agent**: For making changes after understanding structure
- **nextflow-debug agent**: For troubleshooting with structural context

## Best Practices

1. **Always overview first**: Before making any changes, run `overview` to understand what you're working with
2. **Use directory parameter**: When working with multiple pipelines, always specify the directory
3. **Combine tools**: No single tool gives complete picture - use 2-3 in sequence
4. **Check for schema**: If `nextflow_schema.json` exists, run `config_params` for full parameter documentation
5. **Respect token budget**: These tools are designed to minimize context usage - trust their summaries

## Common Patterns

**Pattern 1: First-time exploration**

```
overview → tree → includes → Read specific files
```

**Pattern 2: Quick assessment**

```
component_count → overview → Done (if sufficient)
```

**Pattern 3: Parameter investigation**

```
config_params → overview (if schema exists)
overview → config_params (if no schema)
```

## Notes

- Tools default to current working directory if no directory specified
- All tools handle missing directories gracefully
- ast-grep features require `~/.local/share/opencode/ast-grep` setup
- Tools are optimized for both nf-core and custom pipelines
