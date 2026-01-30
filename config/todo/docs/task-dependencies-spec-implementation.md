# Todo.txt Enhancement Proposal: Task Dependencies and Hierarchies

**Version:** 1.0  
**Date:** 2025-09-08  
**Status:** Draft

## Abstract

This document proposes an extension to the todo.txt format to support task dependencies and hierarchical relationships while maintaining full backward compatibility. The enhancement introduces three new key-value pairs (`id:`, `dep:`, `sup:`) that enable users to express that tasks depend on other tasks or are sub-tasks of larger efforts.

---

## 1. Introduction & Motivation

### 1.1 Problem Statement

The current todo.txt format excels at managing individual tasks but lacks native support for expressing relationships between tasks. Users frequently encounter scenarios where:

1. **Task Dependencies**: Some tasks cannot begin until others are complete (e.g., "Deploy application" depends on "Complete testing")
2. **Task Hierarchies**: Large efforts need to be broken down into manageable sub-tasks (e.g., "Set up workshop" contains sub-tasks "Buy workbench" and "Sell jetski")

### 1.2 Design Goals

- **Backward Compatibility**: Files using the new syntax remain valid todo.txt files
- **Minimal Syntax**: Leverage existing key-value pair conventions
- **Tool Independence**: Implementation remains optional for todo.txt clients
- **Plain Text Preservation**: Relationships remain human-readable in raw text

---

## 2. Formal Specification

### 2.1 Grammar Extensions

This proposal extends the existing todo.txt key-value pair syntax with three new reserved keys:

```abnf
task-relation = id-field / dep-field / sup-field

id-field      = "id:" task-id
dep-field     = "dep:" task-id-list
sup-field     = "sup:" task-id

task-id       = 1*32(ALPHA / DIGIT / "-" / "_")
task-id-list  = task-id *("," task-id)
```

### 2.2 Placement Rules

Task relationship fields follow existing key-value pair conventions:

- May appear anywhere in the task description after the optional priority and creation date
- Multiple relationship fields are permitted per task
- Order of relationship fields within a task is not significant

---

## 3. Syntax Definitions

### 3.1 ID Field (`id:`)

**Purpose**: Assigns a unique identifier to a task for reference by other tasks.

**Syntax**: `id:IDENTIFIER`

**Rules**:

- Each task may have at most one `id:` field
- Task IDs must be unique within the todo.txt file
- Task IDs are case-sensitive
- Permitted characters: letters, numbers, hyphens, underscores
- Maximum length: 32 characters

**Example**:

```
(A) Set up workshop in the @garage id:workshop-setup
```

### 3.2 Dependency Field (`dep:`)

**Purpose**: Indicates this task depends on completion of other tasks before it can begin.

**Syntax**: `dep:ID1[,ID2,...]`

**Rules**:

- A task may have multiple `dep:` fields or comma-separated IDs within a single field
- Referenced task IDs must exist within the same todo.txt file
- Tasks with unmet dependencies should be considered "blocked"
- Circular dependencies are prohibited (see Section 5.1)

**Example**:

```
(C) Deploy application dep:testing,code-review @work
```

### 3.3 Hierarchy Field (`sup:`)

**Purpose**: Designates this task as a sub-task of another task.

**Syntax**: `sup:PARENT_ID`

**Rules**:

- A task may have at most one `sup:` field (single parent)
- The referenced parent task ID must exist within the same todo.txt file
- A task cannot be both a dependency and sub-task of the same parent
- Hierarchical loops are prohibited (see Section 5.2)

**Example**:

```
(B) Buy workbench sup:workshop-setup @garage
```

---

## 4. Behavioral Rules

### 4.1 Task Completion States

#### 4.1.1 Dependencies (`dep:`)

- A task with dependencies is **blocked** until all referenced tasks are marked complete
- Once dependencies are satisfied, the task becomes **ready**
- Completing a task automatically unblocks any dependent tasks

#### 4.1.2 Hierarchies (`sup:`)

- Sub-tasks can be completed independently of their parent task
- A parent task is considered **in progress** if it has incomplete sub-tasks
- Parent task completion behavior is implementation-defined:
  - **Option A**: Parent can be completed regardless of sub-task status
  - **Option B**: Parent auto-completes when all sub-tasks are done
  - **Option C**: Parent cannot be completed while sub-tasks remain

### 4.2 Priority Inheritance

Sub-tasks inherit priority context from their parent task:

- If a parent has priority `(A)`, sub-tasks without explicit priorities should be treated as higher urgency
- Explicit sub-task priorities override inherited priority

### 4.3 Integration with Existing Extensions

#### 4.3.1 Due Dates (`due:`)

- Parent task due dates create implicit deadlines for sub-tasks
- Sub-task due dates must not exceed parent due dates (validation warning)

#### 4.3.2 Recurrence (`rec:`)

- Recurring parent tasks generate new sub-task instances
- Sub-task recurrence is independent of parent recurrence

---

## 5. Edge Case Handling

### 5.1 Circular Dependencies

**Detection**: Use depth-first search to detect dependency cycles.

**Resolution Strategy**:

1. Issue warning to user identifying the cycle
2. Ignore the dependency that creates the cycle (typically the last parsed)
3. Continue processing remaining relationships

**Example**:

```
# Circular dependency - parser should warn and break the cycle
(A) Task A id:a dep:b
(B) Task B id:b dep:a
```

### 5.2 Hierarchical Loops

**Detection**: Traverse parent chain to detect loops.

**Resolution Strategy**:

1. Issue warning identifying the loop
2. Ignore the `sup:` field that creates the loop
3. Treat task as top-level

### 5.3 Orphaned References

When a referenced task ID does not exist:

**For Dependencies (`dep:`)**:

- Issue warning about missing dependency
- Treat task as ready (dependency ignored)

**For Hierarchies (`sup:`)**:

- Issue warning about missing parent
- Treat task as top-level

### 5.4 Duplicate IDs

When multiple tasks share the same ID:

- Issue error for duplicate ID
- Only the first occurrence retains the ID
- Subsequent tasks with the same ID have their `id:` field ignored

---

## 6. Implementation Guidelines

### 6.1 Parsing Algorithm

```python
# Pseudocode for parsing relationships
def parse_task_relationships(todo_lines):
    tasks = {}
    dependencies = {}
    hierarchies = {}

    # First pass: collect all IDs
    for line in todo_lines:
        task_id = extract_id(line)
        if task_id:
            if task_id in tasks:
                warn(f"Duplicate ID: {task_id}")
            else:
                tasks[task_id] = line

    # Second pass: process relationships
    for line in todo_lines:
        deps = extract_dependencies(line)
        parent = extract_parent(line)

        validate_relationships(deps, parent, tasks)

    return build_relationship_graph(dependencies, hierarchies)
```

### 6.2 Dependency Resolution

Implementations should provide:

- **Blocked task identification**: Tasks with unmet dependencies
- **Ready task filtering**: Tasks with all dependencies satisfied
- **Dependency chain visualization**: Show what blocks each task

### 6.3 Hierarchy Display

Recommended display approaches:

- **Indented lists**: Show sub-tasks indented under parents
- **Tree view**: ASCII art tree structure
- **Flat with annotations**: Mark sub-tasks with symbols (e.g., `↳`)

---

## 7. Backward Compatibility

### 7.1 Compatibility Guarantees

- **Existing tools**: Files with new syntax remain valid todo.txt files
- **Safe to ignore**: Tools that don't support relationships will ignore the new fields
- **Graceful degradation**: Tasks display normally without relationship information

### 7.2 Migration Path

Users can gradually adopt the new syntax:

1. Add `id:` fields to tasks that will be referenced
2. Add `dep:` and `sup:` fields to establish relationships
3. Tools can provide validation and visualization as they add support

---

## 8. UI/Display Recommendations

### 8.1 Minimal CLI Annotations

Suggested symbols for command-line interfaces:

- `⏳` or `[BLOCKED]` - Tasks with unmet dependencies
- `↳` or `└─` - Sub-tasks (indented under parent)
- `📋` or `[PARENT]` - Tasks with sub-tasks

### 8.2 List Filtering

Recommended filter commands:

- `todo.sh blocked` - Show only blocked tasks
- `todo.sh ready` - Show tasks with satisfied dependencies
- `todo.sh tree` - Show hierarchical view
- `todo.sh deps TASK_ID` - Show dependency chain for a task

### 8.3 Visual Hierarchy

```
(A) Set up workshop in the @garage id:workshop
  ├─ (B) Sell jetski sup:workshop
  └─ (B) Buy workbench sup:workshop

⏳ (C) Repair lawnmower dep:workshop (blocked by: workshop)
```

---

## 9. Examples

### 9.1 Simple Dependency Chain

```
(A) Write proposal id:proposal @work
(B) Get approval dep:proposal id:approval @work
(C) Start implementation dep:approval @work
```

### 9.2 Multi-level Hierarchy

```
(A) Plan vacation id:vacation @personal
(B) Book flights sup:vacation @travel
(B) Reserve hotel sup:vacation @travel
(C) Research restaurants sup:vacation @travel
(B) Get travel insurance dep:vacation @admin
```

### 9.3 Mixed Dependencies and Hierarchies

```
(A) Launch new feature id:launch @work due:2025-12-01
(B) Complete development sup:launch id:dev @work
(B) Write documentation sup:launch dep:dev @work
(B) Conduct user testing sup:launch dep:dev @work
(C) Deploy to production dep:launch @ops
```

### 9.4 Integration with Existing Extensions

```
(A) Weekly team meeting id:weekly-meeting @work rec:1w due:2025-09-12
(B) Prepare agenda sup:weekly-meeting @work due:2025-09-11
(B) Book conference room dep:weekly-meeting @admin
```

---

## 10. Open Questions & Future Work

### 10.1 Cross-file References

Should task relationships work across multiple todo.txt files? This could enable project-level organization while maintaining file modularity.

### 10.2 Relationship Types

Could the syntax be extended to support additional relationship types?

- `blocks:` (inverse of `dep:`)
- `related:` (informational relationship)
- `template:` (task templates for recurring work)

### 10.3 Time Estimates

How should time estimates interact with dependencies? Could blocked time be calculated based on dependency chains?

### 10.4 Milestone Tasks

Should there be a special designation for milestone tasks that serve as dependency targets but may not represent actionable work?

---

## 11. Reference Implementation

A reference implementation will be provided as a todo.txt action script that:

- Validates relationship syntax
- Detects circular dependencies and orphaned references
- Provides basic visualization of task relationships
- Demonstrates blocked/ready task filtering

---

## Appendix A: Syntax Grammar (ABNF)

```abnf
todo-line     = [priority SP] [creation-date SP] description
description   = *task-element
task-element  = word SP / project / context / key-value / task-relation
task-relation = id-field / dep-field / sup-field

priority      = "(" ALPHA ")"
creation-date = date
project       = "+" 1*project-char
context       = "@" 1*context-char
key-value     = key ":" value

id-field      = "id:" task-id
dep-field     = "dep:" task-id-list
sup-field     = "sup:" task-id

task-id       = 1*32(ALPHA / DIGIT / "-" / "_")
task-id-list  = task-id *("," task-id)

word          = 1*word-char
word-char     = ALPHA / DIGIT / %x21-2B / %x2D-39 / %x3B-7E
project-char  = ALPHA / DIGIT / "_" / "-"
context-char  = ALPHA / DIGIT / "_" / "-"
key           = 1*key-char
value         = 1*value-char
key-char      = ALPHA / DIGIT / "_" / "-"
value-char    = ALPHA / DIGIT / "_" / "-" / ":"

date          = 4DIGIT "-" 2DIGIT "-" 2DIGIT
SP            = %x20
ALPHA         = %x41-5A / %x61-7A
DIGIT         = %x30-39
```

---

## License

This specification is released into the public domain. Implementations may be licensed under any terms chosen by their authors.

---

**Document History**

- Version 1.0 (2025-09-08): Initial draft specification
