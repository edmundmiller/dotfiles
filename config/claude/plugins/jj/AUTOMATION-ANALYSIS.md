# JJ Plugin Automation Analysis & Recommendations

## Executive Summary

This document analyzes the current jj plugin architecture and proposes improvements based on:
- The git-policy.ts reference implementation patterns
- Current hook performance and maintainability challenges
- Opportunities for better workflow automation

## Current Architecture Assessment

### Strengths

1. **Clear Hook Separation**: Three focused hooks (git-to-jj-translator, plan-commit, integration-helper) with distinct responsibilities
2. **Fail-Open Safety**: All hooks gracefully degrade on errors
3. **Read-Only Command Detection**: Git translator correctly allows read-only git commands
4. **Task Classification**: Plan-commit hook distinguishes questions from implementation tasks

### Weaknesses

1. **Multiple Subprocess Calls**: Python hooks spawn jj processes repeatedly for state checks
2. **Limited Context Awareness**: Hooks don't share state or coordinate with each other
3. **Manual Command Mapping**: Git-to-jj translator uses static dictionary instead of dynamic analysis
4. **No Argument Parsing**: Missing flag and option handling (e.g., `jj describe -r @-` vs `jj describe`)
5. **Limited Workflow Automation**: Hooks are reactive rather than proactively suggesting workflows

## Proposed Improvements

### 1. Command Classification System (Inspired by git-policy.ts)

**Current**: Binary classification (read-only vs. write)

**Proposed**: Three-tier classification:

```typescript
enum JJCommandCategory {
  // Safe operations - always allow
  READONLY = [
    'status', 'st', 'log', 'show', 'diff', 'cat', 'file list'
  ],

  // Workflow helpers - offer assistance
  HELPERS = [
    'describe', 'new', 'squash', 'split', 'move', 'edit'
  ],

  // Destructive operations - require confirmation
  DESTRUCTIVE = [
    'abandon', 'restore --from', 'git push --force',
    'rebase --skip-empty=false'
  ]
}
```

**Benefits**:
- More nuanced control over command execution
- Can offer contextual help for HELPERS
- Explicit consent flow for DESTRUCTIVE operations

### 2. Shared State Context Manager

**Problem**: Each hook independently queries jj state, causing redundant subprocess calls.

**Solution**: Create a lightweight state manager:

```typescript
interface JJState {
  currentRevision: {
    changeId: string;
    description: string | null;
    isEmpty: boolean;
    hasParent: boolean;
  };
  workingCopy: {
    hasChanges: boolean;
    changedFiles: string[];
    untrackedFiles: string[];
  };
  bookmark: string | null;
  conflicts: boolean;
  lastFetched: number;  // timestamp
}

class JJStateManager {
  private static cache: JJState | null = null;
  private static cacheTimeout = 1000; // 1 second

  static async getState(): Promise<JJState> {
    // Return cached state if fresh
    // Otherwise, run single jj command with templating
    // Parse and cache result
  }

  static invalidate() {
    this.cache = null;
  }
}
```

**Benefits**:
- Single subprocess call per session instead of multiple
- Consistent state across all hooks
- Performance improvement for rapid command sequences

### 3. Enhanced Git-to-JJ Translation with Argument Parsing

**Current**: Simple prefix matching without argument awareness

**Proposed**: Full command parsing:

```typescript
interface ParsedCommand {
  executable: string;
  subcommand: string;
  flags: Map<string, string | boolean>;
  positional: string[];
  workdir?: string;
}

function parseGitCommand(cmd: string): ParsedCommand {
  // Similar to findGitSubcommand() in git-policy.ts
  // Handle -C, --git-dir, -c config
  // Parse flags and options
  // Identify subcommand
}

function translateToJJ(parsed: ParsedCommand): string {
  // Context-aware translation
  // Preserve flags where applicable
  // Suggest multiple alternatives if ambiguous
}
```

**Example Improvements**:

```bash
# Current behavior
git commit -m "message" → suggests "jj describe -m"

# Enhanced behavior
git commit -m "message" → suggests "jj describe -m" if @ has changes
                       → suggests "jj new -m" if @ is already described
                       → suggests "jj squash -m" if @ has WIP description

git reset --hard HEAD~1 → suggests "jj abandon @" or "jj edit @-"
git rebase -i HEAD~3    → suggests "jj rebase" with interactive hint
```

### 4. Proactive Workflow Suggestions

**New Hook**: `workflow-advisor.py` (PostToolUse for Edit/Write tools)

```python
def analyze_workflow_state(state: JJState) -> List[Suggestion]:
    suggestions = []

    # Pattern: Making changes without description
    if state.workingCopy.hasChanges and not state.currentRevision.description:
        if len(state.workingCopy.changedFiles) >= 3:
            suggestions.append({
                'type': 'reminder',
                'message': 'You have 3+ changed files. Consider using `/jj:commit` to describe your work.'
            })

    # Pattern: Plan description exists but has significant changes
    if state.currentRevision.description?.startswith('plan:'):
        if state.workingCopy.hasChanges:
            suggestions.append({
                'type': 'action',
                'message': 'Plan implemented! Update description with `/jj:commit` to reflect actual work.'
            })

    # Pattern: Multiple conceptually different changes
    if can_split_by_pattern(state.workingCopy.changedFiles):
        suggestions.append({
            'type': 'optimization',
            'message': f'Detected {pattern} files. Consider `/jj:split {pattern}` for cleaner history.'
        })

    return suggestions
```

**Trigger Logic**:
- After 3+ Edit/Write operations: Check if commit description needed
- After significant changes: Suggest splits by pattern
- Before session end: Validate plan vs. actual work

### 5. Smart Auto-Tracking with File Type Detection

**Current**: Blanket `jj file track .` before commits

**Proposed**: Intelligent tracking based on file type:

```python
def should_track_file(filepath: str) -> bool:
    """Determine if file should be auto-tracked."""

    # Always track source code
    if matches_pattern(filepath, SOURCE_PATTERNS):
        return True

    # Never track build artifacts
    if matches_pattern(filepath, IGNORE_PATTERNS):
        return False

    # Ask for unusual files
    if matches_pattern(filepath, REVIEW_PATTERNS):
        return 'prompt'

    return True

# In commit hook
untracked = get_untracked_files()
auto_track = [f for f in untracked if should_track_file(f) == True]
review_track = [f for f in untracked if should_track_file(f) == 'prompt']

if review_track:
    print(f"Review these files before tracking: {review_track}")
```

### 6. Conflict Detection and Resolution Guidance

**New Hook**: `conflict-detector.py` (PostToolUse for jj operations)

```python
def check_conflicts(state: JJState) -> Optional[str]:
    if state.conflicts:
        return """
🚨 **Conflicts detected in working copy**

Use one of these approaches:
1. `jj resolve` - Interactive conflict resolution
2. `jj diff --conflicts` - View conflicted regions
3. `jj abandon @` - Discard conflicted revision (undoable)

**Tip**: Conflicts are stored in commits in jj, so you can work on other revisions while resolving.
        """
    return None
```

### 7. Bookmark (Branch) Management Automation

**Pattern**: Auto-create bookmarks for feature work, auto-push when ready

```python
def suggest_bookmark_creation(state: JJState) -> Optional[str]:
    """Suggest creating a bookmark for substantial work."""

    # Count commits since main
    commits_ahead = count_commits_ahead_of_main(state)

    # Significant work without bookmark
    if commits_ahead >= 3 and not state.bookmark:
        return """
💡 **Consider creating a bookmark**

You have {commits_ahead} commits. Create a bookmark for easier sharing:

```bash
jj bookmark create feature-name
jj git push  # Share with remote
```
        """

    return None
```

### 8. Undo/Redo Operation History Tracker

**Pattern**: Track operation history for easy undo guidance

```python
class OperationHistory:
    """Track recent jj operations for smart undo suggestions."""

    def __init__(self):
        self.operations = []

    def record(self, operation: str, timestamp: int):
        self.operations.append({
            'op': operation,
            'time': timestamp,
            'can_undo': is_undoable(operation)
        })

    def suggest_undo(self) -> str:
        last_op = self.operations[-1]
        return f"""
💡 **Last operation**: {last_op['op']}

To undo: `jj undo` or `jj op restore {get_previous_op_id()}`
See all operations: `jj op log`
        """
```

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
- [ ] Migrate hooks from Python to TypeScript for consistency
- [ ] Implement JJStateManager with caching
- [ ] Add comprehensive argument parsing
- [ ] Create test suite for new modules

### Phase 2: Enhanced Translation (Week 2)
- [ ] Implement three-tier command classification
- [ ] Add context-aware git-to-jj translation
- [ ] Create destructive operation consent flow
- [ ] Extend test coverage for edge cases

### Phase 3: Proactive Automation (Week 3)
- [ ] Build workflow-advisor hook
- [ ] Implement smart file tracking
- [ ] Add conflict detection
- [ ] Create operation history tracker

### Phase 4: Advanced Features (Week 4)
- [ ] Bookmark management automation
- [ ] Pattern-based split suggestions
- [ ] Integration with CI/CD workflows
- [ ] Performance benchmarking and optimization

## Migration Strategy

### Option A: Gradual Migration (Recommended)

1. Keep existing Python hooks functional
2. Add new TypeScript modules alongside
3. Gradually migrate functionality
4. Remove Python hooks when TypeScript coverage is complete

**Benefits**: No disruption, incremental testing, easy rollback

### Option B: Complete Rewrite

1. Implement all functionality in TypeScript
2. Extensive testing in isolated environment
3. Switch over in single deployment

**Benefits**: Clean architecture, better performance

**Risks**: Higher initial complexity, potential for bugs

## Performance Considerations

### Current Performance

```
git-to-jj-translator: ~50ms (no subprocess calls)
plan-commit:         ~200ms (2-3 jj subprocess calls)
integration-helper:  ~300ms (4-5 jj subprocess calls)
```

### Projected Performance (with optimizations)

```
Command classifier:  ~10ms (pure TypeScript, no subprocess)
State manager:       ~100ms (single jj subprocess with caching)
Workflow advisor:    ~50ms (uses cached state)
Total:              ~160ms vs. current ~550ms (71% improvement)
```

## Testing Strategy

### Unit Tests
- [ ] Command parsing accuracy
- [ ] Classification correctness
- [ ] State manager caching behavior
- [ ] Workflow pattern detection

### Integration Tests
- [ ] Hook chaining and coordination
- [ ] Subprocess communication
- [ ] Error handling and graceful degradation
- [ ] Cross-platform compatibility

### End-to-End Tests
- [ ] Real jj repository workflows
- [ ] Multi-command sequences
- [ ] Conflict scenarios
- [ ] Performance benchmarks

## Security Considerations

1. **Command Injection**: Always validate and sanitize subprocess arguments
2. **Path Traversal**: Validate working directory paths
3. **Destructive Operations**: Require explicit consent for dangerous commands
4. **Subprocess Limits**: Prevent fork bombs from malicious commands
5. **Sensitive Data**: Never log commit messages or file contents

## Backward Compatibility

### Breaking Changes
- None for user-facing slash commands
- Hook output format remains JSON
- Existing workflows continue to function

### Deprecations
- Python hooks will be marked deprecated but continue working
- Migration guide provided for custom configurations

## Conclusion

The proposed improvements focus on three key areas:

1. **Performance**: Reduce subprocess overhead through caching and better state management
2. **Intelligence**: Provide context-aware suggestions and proactive workflow guidance
3. **Safety**: Implement proper command classification and consent flows

By following the patterns established in git-policy.ts and building on the solid foundation of the current jj plugin, we can create a more robust, efficient, and helpful automation system for jj workflows.

## Next Steps

1. Review and discuss this proposal
2. Prioritize features based on impact and effort
3. Create detailed implementation specifications
4. Begin Phase 1 implementation
5. Establish metrics for measuring improvement

---

**Document Version**: 1.0
**Last Updated**: 2025-11-09
**Author**: Claude (based on jj plugin analysis)
