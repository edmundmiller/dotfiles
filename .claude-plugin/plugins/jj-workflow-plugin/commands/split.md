---
allowed-tools: Bash(jj log:*), Bash(jj files:*), Bash(jj squash:*), Bash(jj describe:*), Bash(jj new:*)
argument-hint: <pattern>
description: Split commit by pattern (tests, docs, config, etc)
model: sonnet
---

!# Split commit using pattern matching

# Check if we have changes

has_changes=$(jj status --no-pager 2>/dev/null | grep -E "^[AM]" || echo "")

if [ -z "$has_changes" ]; then
echo "ℹ️ No changes to split"
echo ""
jj log -r @ -T 'Current: {change_id.short()}\nDescription: {description}\n' --no-graph
exit 0
fi

if [ -z "$ARGUMENTS" ]; then
echo "❌ **Pattern required**"
echo ""
echo "**Usage:** \`/jj:split <pattern>\`"
echo ""
echo "**Common patterns:**"
echo "- \`test\` - Split test files"
echo "- \`spec\` - Split spec files"
echo "- \`docs\` - Split documentation"
echo "- \`_.md\` - Split markdown files"
echo "- \`config\` - Split config files"
echo "- \`_.test.ts\` - Split TypeScript tests"
echo ""
echo "**Current files:**"
jj files -r @ | head -10
exit 1
fi

pattern="$ARGUMENTS"

# Find files matching pattern

echo "🔍 Finding files matching: **$pattern**"
echo ""

# Build grep pattern based on input

case "$pattern" in
  test|tests)
    files=$(jj files -r @ | grep -E "test|spec|\.test\.|\.spec\." || echo "")
;;
docs|doc)
files=$(jj files -r @ | grep -E "\.md$|README|CHANGELOG|docs/" || echo "")
;;
config|cfg)
files=$(jj files -r @ | grep -E "config|\.json$|\.yaml$|\.yml$|\.toml$" || echo "")
    ;;
  *)
    # Use pattern as-is (supports globs like *.md)
    files=$(jj files -r @ | grep -E "$pattern" || echo "")
;;
esac

if [ -z "$files" ]; then
echo "❌ No files match pattern: **$pattern**"
echo ""
echo "**All files in commit:**"
jj files -r @
exit 1
fi

echo "**Found files:**"
echo "\`\`\`"
echo "$files"
echo "\`\`\`"
echo ""

# Move matched files back to parent (effectively splitting them out)

echo "🔀 Moving files to parent commit..."
echo ""
jj squash --into @- $files 2>&1 || {
echo "❌ Failed to split files"
exit 1
}

# Describe the parent with the split files

jj describe -r @- -m "split: $pattern" 2>/dev/null || true

echo ""
echo "✅ **Files split to parent commit**"
echo ""
echo "**Updated stack:**"
jj log -r ::@ --limit 3 -T '{change_id.short()}: {description}'

echo ""
echo "💡 **Tip:** Use \`jj describe -r @-\` to update the split commit's message"
