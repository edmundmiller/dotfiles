---
name: Setting Up Jujutsu Repositories and Tool Integration
description: Set up jj repositories including colocation decisions, integrate with development tools like Vite/Vitest, and choose between jj library and CLI for tooling. Use when setting up new repositories, experiencing tool integration issues, or building jj integrations.
allowed-tools: Bash(jj init:*), Bash(jj git:*), Read(*/jj-repository-setup/*.md), Edit(.jjconfig.toml), Edit(jj:*.toml), Edit(vite:*.config.*)
---

# Setting Up Jujutsu Repositories and Tool Integration

## Overview

**Key decisions:**
- **Colocation:** Should you use jj and git in the same directory?
- **Tool integration:** How to configure development tools to work with jj
- **Programmatic access:** Library vs CLI for building jj integrations

Understanding these choices helps you set up repositories correctly and avoid common integration issues.

## Repository Setup

### Colocation Decision

**What is colocation?**

Using jj and git in the same working directory:
```
my-repo/
├── .git/     # Git repository
├── .jj/      # Jujutsu repository
└── src/      # Shared working directory
```

**Creating colocated repository:**

```bash
# Initialize jj in existing git repo
cd my-git-repo
jj git init --colocate

# Or create new colocated repo
jj git init --colocate my-repo
cd my-repo
```

**Creating jj-only repository:**

```bash
# Pure jj repository (no colocation)
jj git init my-repo
cd my-repo
```

### Should You Colocate?

**Advantages:**
- ✅ Use both Git and Jujutsu tools on same repo
- ✅ Easier transition/learning (can fall back to git)
- ✅ Works with git-only tools (IDEs, CI/CD)
- ✅ Single working directory

**Drawbacks:**
- ❌ Potential bookmark/branch conflicts
- ❌ Confusing diffs in conflicted files (shows both tools' markers)
- ❌ Slight performance overhead in large repos
- ❌ Can accidentally use git commands (bad practice in jj)

**Recommendation:**

| Scenario | Recommendation |
|----------|----------------|
| Learning jj | Colocate (easier transition) |
| Team migration | Colocate (gradual adoption) |
| New personal project | jj-only (cleaner) |
| Legacy git project | Colocate (tool compatibility) |
| CI/CD requirements | Colocate (git tooling) |

## Tool Integration

### Vite/Vitest Issues

**Problem:** `jj` commands slow or hang in Vite/Vitest projects.

**Cause:** Vite's file watcher monitors `.jj` directory, causing conflicts and slowdowns.

**Solution:** Configure Vite to ignore `.jj`:

```javascript
// vite.config.js or vite.config.ts
export default {
  server: {
    watch: {
      ignored: ['**/.jj/**']
    }
  }
}
```

**For Vitest:**
```javascript
// vitest.config.js or vitest.config.ts
export default {
  test: {
    // ... other config
    watch: {
      ignored: ['**/.jj/**']
    }
  }
}
```

**Complete example:**
```javascript
import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    watch: {
      ignored: [
        '**/.jj/**',      // Ignore jj directory
        '**/.git/**',     // Good practice to ignore git too
        '**/node_modules/**'
      ]
    }
  }
})
```

### General Tool Integration

**Common issues and fixes:**

**File watchers:**
- Exclude `.jj/` from watching
- Pattern: `**/.jj/**` or `.jj`

**IDEs (VS Code, IntelliJ, etc.):**
```json
// .vscode/settings.json
{
  "files.watcherExclude": {
    "**/.jj/**": true
  },
  "search.exclude": {
    "**/.jj/**": true
  }
}
```

**Build tools:**
- Add `.jj/` to ignore patterns
- Similar to `.git/` configuration

**Linters/formatters:**
```yaml
# .prettierignore or .eslintignore
.jj/
```

## Programmatic Integration

### Library vs CLI Trade-offs

**Question:** Should I use the jj library or parse CLI output?

**Answer:** Both have trade-offs. Library avoids parsing but isn't stable. CLI is also unstable but more flexible.

### Using the Library

**Pros:**
- ✅ Native Rust integration
- ✅ No parsing needed
- ✅ Direct access to data structures

**Cons:**
- ❌ API not stable (frequent breaking changes)
- ❌ Rust only (no other languages)
- ❌ Won't detect custom backends
- ❌ Requires Rust knowledge

**When to use:**
- Building Rust tools
- Need high performance
- Want type safety
- Willing to handle API changes

### Using the CLI

**Pros:**
- ✅ Language-agnostic (any language can run commands)
- ✅ Works with custom jj binaries
- ✅ Easier to prototype
- ✅ Matches user experience

**Cons:**
- ❌ Output format can change (also unstable)
- ❌ Parsing overhead
- ❌ Process spawning overhead
- ❌ Need to handle errors/edge cases

**When to use:**
- Building scripts (bash, python, etc.)
- Need portability
- Rapid prototyping
- Want consistency with user commands

### Best Practices for CLI Integration

```bash
# Use --no-pager for scripting
jj log --no-pager

# Use templates for structured output
jj log --template 'commit_id ++ "\t" ++ description.first_line() ++ "\n"'

# Use revsets for precise queries
jj log -r 'mine() & after("1 week ago")'

# Check exit codes
if jj status &>/dev/null; then
  echo "In jj repository"
fi
```

**Example Python integration:**
```python
import subprocess
import json

def jj_log(revset="@"):
    result = subprocess.run(
        ["jj", "log", "-r", revset, "--no-pager",
         "--template", "json"],
        capture_output=True,
        text=True
    )
    return json.loads(result.stdout)
```

## When to Use This Skill

Use this skill when:
- ✅ Setting up new jj repositories
- ✅ Deciding on colocation strategy
- ✅ Experiencing tool integration issues (Vite, IDEs, watchers)
- ✅ Building integrations with jj
- ✅ Choosing between library and CLI approach

Don't use this skill for:
- ❌ Daily jj operations (see jj-workflow skill)
- ❌ Commit management (see commit-curation skill)
- ❌ Understanding jj concepts (see other jj skills)

## Progressive Disclosure

For detailed setup guides, configuration examples, and integration patterns:

📚 **See detailed docs:** `faq-reference.md`

This includes:
- Complete colocation analysis
- Tool-specific integration guides
- Advanced configuration examples
- Library API patterns
- CLI parsing strategies

## Quick Reference

```bash
# Repository initialization
jj git init --colocate           # Colocated repo (jj + git)
jj git init                      # jj-only repo
jj git init --colocate existing-git-repo  # Add jj to git repo

# Configuration
~/.jjconfig.toml                 # Global config
.jj/repo/config.toml             # Repository config

# Tool integration
# Vite: Add to vite.config.js
server.watch.ignored = ['**/.jj/**']

# VS Code: Add to .vscode/settings.json
"files.watcherExclude": {"**/.jj/**": true}
```

## Remember

**Colocation is a choice, not a requirement.** Use it when you need git compatibility, prefer pure jj otherwise. Always configure development tools to ignore `.jj/` directory to avoid conflicts and performance issues.
