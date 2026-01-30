# Todo.txt Documentation

This directory contains comprehensive documentation for the todo.txt action collection and enhancement system.

## Core Documentation

### [ideas.org](ideas.org)

Original brainstorming notes and vision for AI-enhanced todo.txt system. Contains the initial thoughts on integrating AI agents with traditional todo.txt workflow.

### [structured-plan.md](structured-plan.md)

Detailed 20-phase implementation plan for building an AI-enhanced todo.txt task management system. Includes architecture, timeline, and integration strategies.

### [task-dependencies-spec.md](task-dependencies-spec.md)

Formal specification for extending todo.txt format with task dependencies and hierarchies using `id:`, `dep:`, and `sup:` fields.

## Implementation References

### [task-dependencies-spec-implementation.md](task-dependencies-spec-implementation.md)

Implementation-specific version of the dependency specification with practical details.

### [deps-implementation-readme.md](deps-implementation-readme.md)

README from the dependency implementation work, documenting the actual implementation of the dependency system.

### [time-tracking-comparison.md](time-tracking-comparison.md)

Comparison and analysis of different time tracking approaches for todo.txt.

## Archive Documentation

### [README_OPEN.md](README_OPEN.md)

Documentation for the `open` action functionality.

### [WORKTREES.md](WORKTREES.md)

Documentation explaining the preserved git worktrees structure and their purposes.

## Current Status

As of the recent consolidation:

- **Formatters**: Consolidated to Go-based `todotxtfmt` (located in `bin/todotxtfmt/`)
- **Core Actions**: Available in main directory (`deps`, `today`, `tracktime`, `urgency`, etc.)
- **Tests**: Consolidated in `tests/` directory
- **Archive**: Historical implementations preserved in `archive/`

## Next Steps

The structured plan represents ambitious goals for AI enhancement. Current focus should be on:

1. Ensuring core actions work reliably
2. Completing dependency system implementation
3. Deciding on AI enhancement path forward
