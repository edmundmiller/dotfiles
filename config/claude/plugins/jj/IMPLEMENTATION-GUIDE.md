# JJ Plugin Enhanced Implementation Guide

## Quick Start: Testing the Enhanced Git Translator

### 1. Run the Enhanced Translator Tests

```bash
# Make the enhanced translator executable
chmod +x hooks/git-to-jj-translator-enhanced.ts

# Run Deno tests
deno test --allow-all hooks/git-to-jj-translator-enhanced.test.ts

# Or run specific tests
deno test --allow-all --filter "parseGitCommand" hooks/git-to-jj-translator-enhanced.test.ts
```

### 2. Compare Python vs TypeScript Performance

```bash
# Benchmark Python version
time echo '{"tool":{"name":"Bash","params":{"command":"git commit"}}}' | \
  ./hooks/git-to-jj-translator.py

# Benchmark TypeScript version
time echo '{"tool":{"name":"Bash","params":{"command":"git commit"}}}' | \
  ./hooks/git-to-jj-translator-enhanced.ts
```

### 3. Test Context-Aware Suggestions

The enhanced version provides different suggestions based on jj repository state:

```bash
# Test in a jj repository

# Scenario 1: Empty commit, no description
jj new
echo '{"tool":{"name":"Bash","params":{"command":"git commit -m \"test\""}}}' | \
  ./hooks/git-to-jj-translator-enhanced.ts
# Suggests: jj describe -m "test"

# Scenario 2: Has description and changes
jj describe -m "existing work"
echo "test" > test.txt
echo '{"tool":{"name":"Bash","params":{"command":"git commit -m \"more work\""}}}' | \
  ./hooks/git-to-jj-translator-enhanced.ts
# Suggests: jj new -m "more work"
```

## Migration Path: Python to TypeScript

### Option A: Side-by-Side Testing (Recommended)

1. **Keep Python hooks active** in `plugin.json`
2. **Add TypeScript versions** with different names
3. **Compare behavior** using test suite
4. **Gradually migrate** when confident

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "script",
            "script": "./hooks/git-to-jj-translator.py"
          }
        ]
      }
    ]
  }
}
```

Later, switch to:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "script",
            "script": "./hooks/git-to-jj-translator-enhanced.ts"
          }
        ]
      }
    ]
  }
}
```

### Option B: Direct Replacement

1. **Run comprehensive tests** first
2. **Backup current plugin** directory
3. **Update plugin.json** to use TypeScript hooks
4. **Test thoroughly** in real workflows
5. **Roll back** if issues found

## Implementation Checklist

### Phase 1: Enhanced Git Translation ✅

- [x] Create TypeScript git-to-jj translator
- [x] Implement command parsing (based on git-policy.ts)
- [x] Add command classification
- [x] Build context-aware suggestions
- [x] Write comprehensive tests
- [ ] Deploy and test in real usage
- [ ] Document any issues found
- [ ] Performance benchmark vs Python

### Phase 2: State Management

- [ ] Create JJStateManager module
- [ ] Implement caching layer
- [ ] Add invalidation logic
- [ ] Test with rapid command sequences
- [ ] Measure performance improvement

### Phase 3: Workflow Advisor

- [ ] Create workflow-advisor hook
- [ ] Implement pattern detection (test/docs/config splits)
- [ ] Add plan vs. actual validation
- [ ] Test suggestion timing and relevance
- [ ] Gather user feedback

### Phase 4: Advanced Features

- [ ] Smart file tracking
- [ ] Conflict detection
- [ ] Bookmark automation
- [ ] Operation history tracking

## Testing Strategy

### Unit Tests

```bash
# Run all hook tests (Bun)
bun test hooks/jj-hooks.test.mjs

# Run enhanced translator tests (Deno)
deno test --allow-all hooks/git-to-jj-translator-enhanced.test.ts

# Watch mode for development
bun test --watch hooks/jj-hooks.test.mjs
```

### Integration Tests

```bash
# Create test repository
mkdir /tmp/jj-test && cd /tmp/jj-test
jj git init --colocate

# Test workflow scenarios
jj new
echo "test" > file.txt

# Simulate Claude Code hook execution
echo '{"tool":{"name":"Bash","params":{"command":"git add ."}}}' | \
  /path/to/hooks/git-to-jj-translator-enhanced.ts
```

### Performance Benchmarks

```bash
# Create benchmark script
cat > benchmark.sh << 'EOF'
#!/bin/bash

echo "Benchmarking Python version..."
time for i in {1..100}; do
  echo '{"tool":{"name":"Bash","params":{"command":"git commit"}}}' | \
    ./hooks/git-to-jj-translator.py > /dev/null
done

echo "Benchmarking TypeScript version..."
time for i in {1..100}; do
  echo '{"tool":{"name":"Bash","params":{"command":"git commit"}}}' | \
    ./hooks/git-to-jj-translator-enhanced.ts > /dev/null
done
EOF

chmod +x benchmark.sh
./benchmark.sh
```

## Common Issues and Solutions

### Issue: Deno not found

```bash
# Install Deno
curl -fsSL https://deno.land/install.sh | sh

# Or via Homebrew
brew install deno

# Or via Nix
nix profile install nixpkgs#deno
```

### Issue: Permission denied

```bash
# Make hooks executable
chmod +x hooks/*.ts hooks/*.py
```

### Issue: JJ state queries slow

```typescript
// Use caching in JJStateManager
class JJStateManager {
  private static cache: JJState | null = null;
  private static cacheTime = 0;
  private static CACHE_TTL = 1000; // 1 second

  static async getState(): Promise<JJState> {
    const now = Date.now();
    if (this.cache && (now - this.cacheTime) < this.CACHE_TTL) {
      return this.cache;
    }

    // Fetch fresh state
    this.cache = await this.fetchState();
    this.cacheTime = now;
    return this.cache;
  }
}
```

### Issue: Context-aware suggestions not working

```bash
# Check if jj is available
which jj

# Verify jj repository
jj status

# Test state queries manually
jj log -r @ --no-graph -T 'if(description, "has", "none")'
jj log -r @ --no-graph -T 'if(empty, "empty", "has_changes")'
```

## Code Quality Standards

### TypeScript

- Use strict mode
- No any types without justification
- Comprehensive error handling
- Document all public functions
- Test coverage > 80%

### Python

- Type hints for all functions
- Docstrings for all modules/functions
- Follow PEP 8 style guide
- Use mypy for type checking

### Tests

- Unit tests for all pure functions
- Integration tests for hook workflows
- Performance benchmarks for critical paths
- Edge case coverage

## Metrics and Monitoring

### Performance Metrics

```typescript
// Add timing to hooks
const startTime = performance.now();
// ... hook logic ...
const duration = performance.now() - startTime;

console.error(`Hook execution time: ${duration}ms`);
```

### Success Metrics

- **Reduction in subprocess calls**: Target 60% reduction
- **Hook execution time**: Target <150ms average
- **Translation accuracy**: Target 95% for common commands
- **User satisfaction**: Gather feedback via surveys

## Next Steps

1. **Review this guide** with team/users
2. **Run Phase 1 tests** in isolated environment
3. **Deploy to staging** (if available)
4. **Gradual rollout** to production
5. **Monitor metrics** and gather feedback
6. **Iterate** based on learnings

## Resources

- [Jujutsu Documentation](https://jj-vcs.github.io/jj/)
- [Git to JJ Command Table](https://jj-vcs.github.io/jj/latest/git-command-table/)
- [Claude Code Plugin API](https://docs.claude.com/en/docs/claude-code/plugins)
- [git-policy.ts Reference](https://github.com/steipete/agent-scripts/blob/main/scripts/git-policy.ts)

## Contributing

Found a bug or have a suggestion? Please:

1. Check existing issues
2. Create detailed bug report or feature request
3. Include reproduction steps
4. Propose solutions when possible

---

**Last Updated**: 2025-11-09
**Version**: 1.0
