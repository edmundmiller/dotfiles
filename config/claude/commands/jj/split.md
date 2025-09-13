---
allowed-tools: Bash(jj split*), Bash(jj status*), Bash(jj diff*), Bash(jj log*), Bash(jj op log*)
description: Help split mixed changes into separate commits
---

## Context

- Current changes: !`jj status`
- Working copy: !`jj log -r @ --no-graph`
- Diff preview: !`jj diff --summary`
- Recent operations: !`jj op log --limit 5`

## Your task

Help the user split the current working copy changes into multiple logical commits. This is especially useful when multiple unrelated changes have been made together.

### Split Methods

#### 1. Interactive Split (with hunk.nvim)
```bash
jj split  # Opens diff editor to select changes
```
This will open your configured diff editor (hunk.nvim) where you can:
- Select individual hunks or lines to keep in the first commit
- Remaining changes become a new child commit
- Use `a` to toggle lines, `A` for hunks, `<leader><CR>` to accept

#### 2. Path-based Split
```bash
jj split -i path/to/file1 path/to/file2  # Split specific files
jj split -i '*.test.js'                  # Split by pattern
```

#### 3. Split Points to Consider
When helping split changes, look for:
- Unrelated bug fixes mixed with features
- Test files that should be separate from implementation
- Documentation updates that could be standalone
- Refactoring mixed with new functionality
- Config changes separate from code changes

### Common Workflows

**Split after Claude makes multiple changes:**
```bash
jj diff --summary      # Review what changed
jj split              # Interactive split
jj log -r ::@         # See the new commit structure
```

**Split and describe each part:**
```bash
jj split                           # Split changes
jj describe -r @- -m "fix: ..."   # Describe first part
jj describe -m "feat: ..."         # Describe second part
```

### Important Notes
- Split creates a parent-child relationship between commits
- The working copy (`@`) becomes the child with remaining changes
- Use `jj op undo` if the split didn't work as intended
- After splitting, you may want to `jj squash` different parts into other commits

Ask the user:
- Should we split interactively or by file paths?
- How should the changes be logically grouped?
- Do they want help writing descriptions for each part?