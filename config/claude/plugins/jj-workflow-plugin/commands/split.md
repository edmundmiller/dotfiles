---
allowed-tools: Bash(jj log:*), Bash(jj diff:*), Bash(jj status:*), Bash(jj split:*)
argument-hint: <pattern>
description: Split commit by pattern (tests, docs, config, etc)
model: claude-haiku-4-5
---

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
echo "**Example:** \`/jj:split test\`"
exit 0
fi

## Context

- Current status: !`jj status`
- Current commit: !`jj log -r @ --no-graph -T 'concat(change_id.short(), ": ", description)'`
- Parent commit: !`jj log -r @- --no-graph -T 'concat(change_id.short(), ": ", description)'`

## Your Task

Split the current commit (@) by moving files matching the pattern "$ARGUMENTS" to the parent commit (@-).

**Pattern Expansion:**

- `test` → Match test files: `*test*.{py,js,ts,jsx,tsx,java,go,rs,cpp,c,h}`, `*spec*.{py,js,ts,jsx,tsx}`, `test_*.py`, `*_test.go`, `*Test.java`
- `docs` → Match documentation: `*.md`, `README*`, `CHANGELOG*`, `LICENSE*`, `docs/**/*`
- `config` → Match config files: `*.json`, `*.yaml`, `*.yml`, `*.toml`, `*.ini`, `*.conf`, `.*.rc`, `.*ignore`
- Custom patterns → Use as-is (glob syntax)

**How jj split works:**

1. Moves matching files from current commit (@) to parent commit (@-)
2. Leaves non-matching files in current commit (@)
3. Effectively "splits out" the matching files into a separate commit

**Steps:**

1. First, show what files match the pattern by analyzing the current changes
2. Explain what will be moved to the parent commit
3. Use `jj split` with appropriate glob pattern(s)
4. Show the result with `jj log` and `jj status`

**Important:**

- Use `-p` flag with glob patterns: `jj split -p 'glob:pattern'`
- For multiple patterns, use multiple `-p` flags: `jj split -p 'glob:*.md' -p 'glob:README*'`
- Always quote glob patterns to prevent shell expansion
- If no files match, inform the user and suggest alternatives

**Example commands:**

```bash
# Split test files
jj split -p 'glob:**/*test*.py' -p 'glob:**/*_test.py'

# Split documentation
jj split -p 'glob:*.md' -p 'glob:README*' -p 'glob:docs/**'

# Split config files
jj split -p 'glob:*.json' -p 'glob:*.yaml' -p 'glob:*.toml'
```

Show result: !`jj log -r '@|@-' --no-graph -T 'concat(change_id.short(), ": ", description)'`
