---
allowed-tools: Bash(jj log:*), Bash(jj diff:*), Bash(jj status:*), Bash(jj new:*), Bash(jj move:*), Bash(jj describe:*), Bash(~/bin/jj-ai-desc.py:*)
argument-hint: <pattern>
description: Split unwanted changes into new child commit with AI description
model: claude-haiku-4-5
---

!# Source utility scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../hooks/jj-state.sh"
source "$SCRIPT_DIR/../hooks/jj-templates.sh"

!# Validate pattern argument

if [ -z "$ARGUMENTS" ]; then
echo "❌ **Error: Pattern required**"
echo ""
echo "**Usage:** \`/jj:split <pattern>\`"
echo ""
echo "**Common patterns:**"
echo "- \`test\` - Test and spec files"
echo "- \`docs\` - Documentation (_.md, README, CHANGELOG)"
echo "- \`config\` - Config files (_.json, _.yaml, _.toml)"
echo "- Custom glob patterns (e.g., \`_.md\`, \`src/\*\*/_.test.ts\`)"
echo ""
echo "**What it does:**"
echo "1. Keeps wanted changes in current commit (@)"
echo "2. Moves unwanted (matching pattern) changes to new child commit"
echo "3. Auto-generates description for child commit"
echo ""
echo "**Example:** \`/jj:split test\` - splits test files into new child commit"
exit 0
fi

## Context

- Current status: !`jj status`
- Current commit: !`format_commit_short`
- Changed files: !`jj diff -r @ --summary`

## Your Task

Split unwanted changes matching pattern "$ARGUMENTS" from current commit (@) into a new child commit with an AI-generated description.

**Pattern Expansion:**

- `test` → Match test files: `*test*.{py,js,ts,jsx,tsx,java,go,rs,cpp,c,h}`, `*spec*.{py,js,ts,jsx,tsx}`, `test_*.py`, `*_test.go`, `*Test.java`
- `docs` → Match documentation: `*.md`, `README*`, `CHANGELOG*`, `LICENSE*`, `docs/**/*`
- `config` → Match config files: `*.json`, `*.yaml`, `*.yml`, `*.toml`, `*.ini`, `*.conf`, `.*.rc`, `.*ignore`
- Custom patterns → Use as-is (glob syntax)

**Workflow:**

1. **Identify matching files** - Show which files in current commit match the pattern
2. **Create child commit** - `jj new @` to create empty child where split changes will go
3. **Move matching changes** - `jj move --from @- -p 'glob:pattern'` to move unwanted files from parent to child
4. **Generate description** - Use `~/bin/jj-ai-desc.py @` to analyze split changes and generate commit message
5. **Show result** - Display final commit structure

**Result structure:**

```
@ (new child): unwanted changes with AI description
@- (original): wanted changes, original description preserved
```

**Important notes:**

- Use multiple `-p` flags for multiple patterns: `jj move --from @- -p 'glob:*.md' -p 'glob:README*'`
- Always quote glob patterns: `'glob:pattern'`
- The original commit description stays intact, only the unwanted changes move
- If no files match, inform user and suggest alternatives
- After moving, the AI will analyze what was split and generate an appropriate description

**Example execution:**

```bash
# Split test files
jj new @
jj move --from @- -p 'glob:**/*test*.py' -p 'glob:**/*_test.py'
~/bin/jj-ai-desc.py @

# Split documentation
jj new @
jj move --from @- -p 'glob:*.md' -p 'glob:README*' -p 'glob:docs/**'
~/bin/jj-ai-desc.py @

# Split config files
jj new @
jj move --from @- -p 'glob:*.json' -p 'glob:*.yaml' -p 'glob:*.toml'
~/bin/jj-ai-desc.py @
```

**Final verification:**

Show the result: !`format_commit_list '@|@-'`
