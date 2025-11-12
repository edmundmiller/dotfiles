# Repository Setup and Tool Integration - Detailed FAQ

## Q: Should I colocate my repository?

**Answer:** Colocating allows using both Git and Jujutsu in one copy, helpful for tooling and learning. Drawbacks include potential bookmark conflicts, confusing diffs in conflicted files, and slight performance overhead in large repos.

### Complete Colocation Analysis

**What is colocation?**

Colocated repository = Git and Jujutsu sharing the same working directory.

```
colocated-repo/
├── .git/          # Git's data
│   ├── objects/
│   ├── refs/
│   └── ...
├── .jj/           # Jujutsu's data
│   ├── repo/
│   ├── working_copy/
│   └── ...
└── src/           # Your files (shared)
```

**How it works:**
- Both tools read from same files
- jj syncs with git automatically
- Can use both `git` and `jj` commands
- Working directory shared between both

### Setting Up Colocation

**Method 1: Add jj to existing git repo**

```bash
cd my-git-repo
jj git init --colocate

# Verify
ls -la  # Should see both .git and .jj
jj log  # Should show git history
git log # Still works
```

**Method 2: Create new colocated repo**

```bash
jj git init --colocate my-new-repo
cd my-new-repo

# Initialize git remote
jj git remote add origin https://github.com/user/repo.git
```

**Method 3: Clone colocated**

```bash
jj git clone --colocate https://github.com/user/repo.git
cd repo
# Both .git and .jj exist
```

### Advantages in Detail

#### 1. Tool Compatibility

**Git-based tools still work:**
```bash
# IDEs with git integration
# GitHub Desktop, GitKraken, etc.
# CI/CD systems expecting git
# Team members using git
```

**Example:** VS Code git features work normally while you use jj.

#### 2. Learning Curve

**Easier transition:**
```bash
# Try jj commands
jj log

# Fall back to git when unsure
git log

# Compare behaviors
jj status
git status
```

You can learn jj gradually without commitment.

#### 3. Incremental Adoption

**Team migration scenario:**
```bash
# Developer 1 (uses jj)
jj new -m "feature"
jj git push --change @

# Developer 2 (uses git)
git pull
git checkout -b feature
git push origin feature

# Both workflows work!
```

#### 4. Hybrid Workflows

**Use best of both:**
```bash
# Use jj for local work
jj new -m "feature"
jj split -i

# Use git for specific operations
git bisect start
git bisect bad HEAD
git bisect good v1.0
```

### Drawbacks in Detail

#### 1. Bookmark/Branch Conflicts

**The issue:**

Git branches and jj bookmarks sync, but naming can conflict.

```bash
# Create branch in git
git checkout -b feature
git commit -m "change"

# Switch to jj
jj log  # Shows feature bookmark
jj bookmark set feature  # Might conflict with git's branch

# After fetch, can have:
# feature (local jj bookmark)
# feature@origin (remote git branch)
# Conflicts arise
```

**Mitigation:**
```bash
# Use consistent naming
# Always use jj for bookmark management
# Or always use git for branches (pick one)

# Clear conflict resolution strategy
jj bookmark move feature --to <desired-commit>
```

#### 2. Confusing Diffs in Conflicts

**The problem:**

When files have conflicts, both git and jj add markers.

```bash
# Git conflict markers
<<<<<<< HEAD
git version
=======
other version
>>>>>>> feature

# Jj also adds its own markers
<<<<<<< Conflict 1 of 1
%%%%%%% Changes from base to side #1
-old content
+jj version
+++++++ Contents of side #2
other version
>>>>>>>
```

**Mitigation:**
```bash
# Resolve conflicts in one tool only
# Prefer jj conflict resolution
jj edit <conflicted-commit>
# Edit files to resolve
# Don't use git merge tools
```

#### 3. Performance Overhead

**The issue:**

Jj maintains additional state and syncs with git.

```bash
# In large repos (100k+ commits)
# jj commands slightly slower than pure jj repo
# Negligible for most repos (<10k commits)
```

**Benchmarks (example):**
```
Pure jj repo:  jj log --limit 100   0.05s
Colocated:     jj log --limit 100   0.07s

Pure jj repo:  jj status            0.03s
Colocated:     jj status            0.04s
```

**Mitigation:**
- Performance hit usually unnoticeable
- For massive repos, consider pure jj
- Or tune git config for performance

#### 4. Accidental Git Usage

**The problem:**

Muscle memory might lead to git commands.

```bash
# Accidentally use git
git commit -m "feature"  # Wrong! Use jj

# Now state is inconsistent
jj log  # Doesn't show git commit immediately
```

**Mitigation:**
```bash
# Block git write commands (recommended)
# Add to .git/hooks/pre-commit:
#!/bin/bash
echo "Error: Use jj commands instead of git"
exit 1

# Or use shell aliases
alias git='echo "Use jj instead!" && false'
```

### Decision Matrix

**Choose colocation if:**

| Criterion | Importance | Notes |
|-----------|------------|-------|
| Team uses git | HIGH | Required for mixed teams |
| Learning jj | HIGH | Easier transition |
| IDE git features | MEDIUM | Keeps tools working |
| CI/CD git-based | HIGH | Essential for compatibility |
| Large repo | LOW | Small performance cost |

**Choose pure jj if:**

| Criterion | Importance | Notes |
|-----------|------------|-------|
| New project | HIGH | Clean slate |
| Solo/jj-only team | HIGH | No git needed |
| Want performance | LOW | Minimal difference |
| Simplicity | MEDIUM | One tool, clearer |

### Migration Strategies

**From colocated to pure jj:**

```bash
# Export git history
cd colocated-repo
jj git export  # Ensure jj has all git data

# Create pure jj repo
cd ..
jj git init pure-jj-repo

# Import history
cd pure-jj-repo
jj git import ../colocated-repo/.git

# Or simpler: just delete .git
cd colocated-repo
rm -rf .git
# Now pure jj (but can't push to git remotes)
```

**From pure jj to colocated:**

```bash
# Initialize git in existing jj repo
cd pure-jj-repo
git init
jj git export  # Export jj history to git

# Or reinitialize as colocated
cd ..
mv pure-jj-repo pure-jj-repo.bak
jj git init --colocate pure-jj-repo
# Manually copy .jj/ from backup
```

## Q: I'm experiencing jj command issues in a Vite/Vitest project. How do I fix this?

**Answer:** Configure Vite to ignore `.jj` directory in `server.watch.ignored` to prevent conflicts and slowdowns.

### Understanding the Problem

**What happens:**

Vite's development server watches files for changes to enable hot module replacement (HMR).

```
Your actions:
1. Run jj command
2. jj modifies .jj/ directory
3. Vite detects .jj/ changes
4. Vite triggers rebuild
5. jj command slow/hangs waiting for Vite
```

**Symptoms:**
- `jj status` hangs
- `jj log` very slow
- High CPU usage during jj commands
- Vite console shows many file change events

### Solution for Vite

**Basic configuration:**

```javascript
// vite.config.js
import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    watch: {
      ignored: ['**/.jj/**']
    }
  }
})
```

**TypeScript configuration:**

```typescript
// vite.config.ts
import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    watch: {
      ignored: ['**/.jj/**']
    }
  }
})
```

**Complete configuration with best practices:**

```javascript
// vite.config.js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    watch: {
      ignored: [
        '**/.jj/**',           // Jujutsu
        '**/.git/**',          // Git (good practice)
        '**/node_modules/**',  // Node modules (usually default)
        '**/.DS_Store',        // macOS
        '**/dist/**',          // Build output
        '**/coverage/**'       // Test coverage
      ]
    }
  }
})
```

### Solution for Vitest

**Basic configuration:**

```javascript
// vitest.config.js
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    watch: {
      ignored: ['**/.jj/**']
    }
  }
})
```

**Combined Vite + Vitest:**

```javascript
// vite.config.js (serves both)
import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    watch: {
      ignored: ['**/.jj/**']
    }
  },
  test: {
    watch: {
      ignored: ['**/.jj/**']
    }
  }
})
```

### Verification

**Check if working:**

```bash
# Start Vite dev server
npm run dev

# In another terminal, run jj commands
jj status  # Should be fast now
jj log     # No hanging

# Check Vite output
# Should NOT show .jj/ file changes
```

### Other Tool Integrations

**Similar issues with other tools:**

#### Webpack

```javascript
// webpack.config.js
module.exports = {
  devServer: {
    watchOptions: {
      ignored: ['**/.jj/**', '**/node_modules/**']
    }
  }
}
```

#### Next.js

```javascript
// next.config.js
module.exports = {
  webpack: (config) => {
    config.watchOptions = {
      ignored: ['**/.jj/**', '**/node_modules/**']
    }
    return config
  }
}
```

#### Jest

```javascript
// jest.config.js
module.exports = {
  watchPathIgnorePatterns: [
    '<rootDir>/.jj/',
    '<rootDir>/node_modules/'
  ]
}
```

#### Nodemon

```json
// nodemon.json
{
  "ignore": [
    ".jj/*",
    "node_modules/*"
  ]
}
```

## Q: Should I use the jj library or parse the CLI for tool integration?

**Answer:** Trade-offs exist. The library avoids parsing but isn't stable. CLI is also unstable. Library won't detect custom backends; CLI will work with custom binaries.

### Library Integration (Rust)

**Using jj as a library:**

```toml
# Cargo.toml
[dependencies]
jj-lib = "0.x.x"  # Check latest version
```

**Basic example:**

```rust
use jj_lib::backend::Backend;
use jj_lib::repo::Repo;
use jj_lib::workspace::Workspace;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Open workspace
    let workspace = Workspace::load(std::env::current_dir()?)?;

    // Get repo
    let repo = workspace.repo_loader().load()?;

    // Access commit data
    let commit_id = repo.view().get_wc_commit_id()?;
    let commit = repo.store().get_commit(commit_id)?;

    println!("Current commit: {}", commit.description());

    Ok(())
}
```

**Pros:**
- ✅ Type-safe access to data structures
- ✅ No parsing overhead
- ✅ Direct API calls
- ✅ Can extend jj functionality

**Cons:**
- ❌ **API instability**: Frequent breaking changes
- ❌ **Rust only**: Can't use from Python, JavaScript, etc.
- ❌ **Custom backends**: Won't detect if user has custom jj binary
- ❌ **Maintenance**: Must update with jj releases

**When to use:**
- Building Rust tools/extensions
- Need maximum performance
- Want type safety
- Can handle API changes (willing to update frequently)

### CLI Integration (Any Language)

**Using CLI with structured output:**

**Bash example:**

```bash
#!/bin/bash

# Get commit info as structured output
jj log -r @ --template '
  commit_id.short() ++ "\t" ++
  description.first_line() ++ "\t" ++
  author.email()
' --no-pager

# Or use JSON (if template supports it)
jj log -r @ --template json --no-pager
```

**Python example:**

```python
import subprocess
import json

def jj_log(revset="@"):
    """Get jj log output as structured data."""
    result = subprocess.run(
        [
            "jj", "log",
            "-r", revset,
            "--no-pager",
            "--template",
            'commit_id.short() ++ "\t" ++ description.first_line()'
        ],
        capture_output=True,
        text=True,
        check=True
    )

    # Parse tab-separated output
    commits = []
    for line in result.stdout.strip().split('\n'):
        if line:
            commit_id, description = line.split('\t', 1)
            commits.append({
                'id': commit_id,
                'description': description
            })

    return commits

# Usage
commits = jj_log("ancestors(@, 5)")
for commit in commits:
    print(f"{commit['id']}: {commit['description']}")
```

**JavaScript/Node.js example:**

```javascript
const { execSync } = require('child_process');

function jjLog(revset = '@') {
  const output = execSync(
    `jj log -r "${revset}" --no-pager --template '` +
    `commit_id.short() ++ "\\t" ++ description.first_line()'`,
    { encoding: 'utf-8' }
  );

  return output.trim().split('\n').map(line => {
    const [id, description] = line.split('\t');
    return { id, description };
  });
}

// Usage
const commits = jjLog('ancestors(@, 5)');
commits.forEach(c => console.log(`${c.id}: ${c.description}`));
```

**Pros:**
- ✅ **Language-agnostic**: Works from any language
- ✅ **Custom binaries**: Uses whatever `jj` is in PATH
- ✅ **User consistency**: Same as user's CLI experience
- ✅ **Easy prototyping**: Quick scripts

**Cons:**
- ❌ **Output instability**: CLI output can change
- ❌ **Parsing complexity**: Must handle various formats
- ❌ **Performance**: Process spawning overhead
- ❌ **Error handling**: String parsing of errors

**When to use:**
- Scripting (bash, python, node)
- Multi-language projects
- Want to use user's jj configuration
- Building user-facing tools

### Best Practices for CLI Integration

**1. Use templates for structured output:**

```bash
# Good: Predictable format
jj log --template 'commit_id.short() ++ "\t" ++ description.first_line()'

# Bad: Free-form output (changes between versions)
jj log
```

**2. Always use --no-pager:**

```bash
# Good: Full output
jj log --no-pager

# Bad: May truncate or paginate
jj log
```

**3. Use revsets for queries:**

```bash
# Good: Precise
jj log -r 'mine() & after("1 week ago")'

# Bad: Parsing full log
jj log | grep "my-email"
```

**4. Handle errors properly:**

```python
try:
    result = subprocess.run(
        ["jj", "status"],
        capture_output=True,
        text=True,
        check=True
    )
except subprocess.CalledProcessError as e:
    print(f"Error: {e.stderr}")
    # Handle error (not in jj repo, etc.)
```

**5. Check for jj repo:**

```python
def is_jj_repo():
    try:
        subprocess.run(
            ["jj", "status"],
            capture_output=True,
            check=True
        )
        return True
    except subprocess.CalledProcessError:
        return False
```

### Hybrid Approach

**Use both when appropriate:**

```rust
// performance-critical parts: use library
use jj_lib::repo::Repo;

fn get_commit_count(repo: &Repo) -> usize {
    // Fast direct access
    repo.view().heads().len()
}

// User-facing commands: use CLI
fn run_user_command(cmd: &str) {
    std::process::Command::new("jj")
        .args(cmd.split_whitespace())
        .status()
        .expect("Failed to run jj");
}
```

### Future Considerations

**API stabilization:**

The jj project is working toward API stability. Check:
- [GitHub discussions](https://github.com/martinvonz/jj/discussions)
- Release notes for API changes
- Deprecation warnings

**Recommendations:**

| Scenario | Recommendation |
|----------|----------------|
| Rust tool, stable API needed | Wait for 1.0 or accept updates |
| Quick script | Use CLI |
| Multi-language | Use CLI |
| Performance-critical | Consider library with update plan |
| User-facing tool | Use CLI (matches user's jj) |
| Internal tool | Library acceptable if can update |

## Additional Setup Topics

### Configuring jj

**Global configuration:**

```toml
# ~/.jjconfig.toml

[user]
name = "Your Name"
email = "you@example.com"

[ui]
default-command = "log"
pager = "less -FRX"

[revsets]
mine = "author(you@example.com)"
recent = "ancestors(@, 20)"

[aliases]
st = ["status"]
l = ["log", "-r", "recent"]
```

**Repository configuration:**

```toml
# .jj/repo/config.toml

[snapshot]
auto-track = "all"  # or "none", or glob patterns

[git]
private-commits = "description(glob:'private:*')"
```

### Setting Up Git Remotes

```bash
# Add remote
jj git remote add origin https://github.com/user/repo.git

# List remotes
jj git remote list

# Remove remote
jj git remote remove origin

# Fetch from remote
jj git fetch
```

### IDE Integration Examples

**VS Code:**

```json
// .vscode/settings.json
{
  "files.watcherExclude": {
    "**/.jj/**": true
  },
  "search.exclude": {
    "**/.jj/**": true
  },
  "files.exclude": {
    "**/.jj": true  // Hide from file explorer
  }
}
```

**IntelliJ/WebStorm:**

```xml
<!-- .idea/workspace.xml -->
<component name="VcsManagerConfiguration">
  <ignored-roots>
    <path value="$PROJECT_DIR$/.jj" />
  </ignored-roots>
</component>
```

### CI/CD Integration

**GitHub Actions:**

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      # Install jj
      - name: Install jj
        run: |
          cargo install jj-cli

      # Use jj commands
      - name: Check jj status
        run: jj status

      # Or use git (if colocated)
      - name: Git operations
        run: git log
```

## Reference: Setup Commands

```bash
# Repository initialization
jj git init                           # Pure jj repo
jj git init --colocate                # Colocated repo
jj git init --colocate existing-repo  # Add jj to git repo
jj git clone URL                      # Clone as pure jj
jj git clone --colocate URL           # Clone as colocated

# Configuration
jj config list                        # List all config
jj config get user.email              # Get specific value
jj config set user.email "me@example.com"  # Set value
jj config set --user key value        # Set in ~/.jjconfig.toml
jj config set --repo key value        # Set in .jj/repo/config.toml

# Remotes
jj git remote add <name> <url>        # Add remote
jj git remote list                    # List remotes
jj git remote remove <name>           # Remove remote
jj git fetch                          # Fetch from remotes
```
