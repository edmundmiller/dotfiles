# Todo.txt Formatter Test Plan

## Overview

This document outlines the comprehensive testing strategy for the Go-based todo.txt formatter, covering all edge cases, error conditions, and performance scenarios.

## Test Categories

### 1. Basic Formatting Tests

**Purpose**: Verify fundamental formatting capabilities

**Test Cases**:
- ✅ Simple tasks without metadata
- ✅ Tasks with priorities: `(A)`, `(B)`, `(C)`
- ✅ Completed tasks: `x 2025-01-01 Task description`
- ✅ Tasks with excessive spacing
- ✅ Tasks with leading/trailing whitespace
- ✅ Mixed priority and completion status

**Expected Behavior**:
- Normalize spacing to single spaces between words
- Preserve priority at start of line: `(A) Task`
- Preserve completion format: `x YYYY-MM-DD Task`
- Remove leading/trailing whitespace
- Maintain proper task structure

### 2. Metadata Preservation Tests

**Purpose**: Ensure all key-value pairs are preserved correctly

**Test Cases**:
- ✅ Due dates: `due:2025-01-15`
- ✅ Issue tracking: `issue:BUG-123`, `pr:456`
- ✅ Custom metadata: `priority:high`, `assignee:developer`
- ✅ Multiple metadata per task
- ✅ Context tags: `@work`, `@personal`
- ✅ Project tags: `+webapp`, `+mobile`

**Expected Behavior**:
- All `key:value` pairs preserved
- Context and project tags maintained
- Metadata positioned after task description
- No corruption of special characters in values

### 3. Issue Tracking Tests

**Purpose**: Verify support for various issue tracking systems

**Test Cases**:
- ✅ JIRA-style: `issue:PROJ-123`
- ✅ GitHub-style: `issue:456`, `pr:789`
- ✅ Agile metadata: `epic:feature-x`, `story-points:5`
- ✅ Sprint tracking: `sprint:2025-Q1`, `velocity:8`
- ✅ Custom tracking: `ticket:ABC-999`, `reviewer:admin`

**Expected Behavior**:
- Issue IDs with various formats preserved
- Alphanumeric issue identifiers supported
- Special characters in issue IDs maintained
- Multiple tracking metadata coexist

### 4. Special Characters Tests

**Purpose**: Handle complex values with special characters

**Test Cases**:
- ✅ URLs: `url:https://example.com/path?param=value`
- ✅ Email addresses: `email:user@domain.com`
- ✅ Phone numbers: `phone:+1-800-555-0123`
- ✅ File paths: `path:/var/log/app.log`
- ✅ Percentages: `uptime:99.9%`, `threshold:95%`
- ✅ Version numbers: `version:1.2.3-beta`
- ✅ Branch names: `branch:feature/auth-improvements`
- ✅ Timestamps: `time:2025-01-20T14:30:00Z`

**Expected Behavior**:
- Special characters preserved in values
- URL parameters and anchors maintained
- Email format integrity
- Path separators preserved
- Complex version strings intact

### 5. Complex Scenario Tests

**Purpose**: Test realistic, complex todo entries

**Test Cases**:
- ✅ Full format: `(A) 2025-01-15 Fix bug @work +webapp issue:CRIT-999 severity:high due:2025-01-20`
- ✅ Multiple contexts: `@work @remote @client-site`
- ✅ Multiple projects: `+webapp +mobile +api`
- ✅ Extensive metadata: 10+ key-value pairs per task
- ✅ Mixed completion and priority states

**Expected Behavior**:
- All elements preserved in correct positions
- Priority and completion status at start
- Contexts and projects after description
- Metadata at end of line
- Consistent spacing throughout

### 6. Edge Cases Tests

**Purpose**: Handle unusual or problematic inputs

**Test Cases**:
- ✅ Empty lines (preserved or removed per library)
- ✅ Whitespace-only lines
- ✅ Comment lines: `# This is a comment`
- ✅ Malformed priorities: `Task (A) with priority in middle`
- ✅ Invalid priority formats: `(invalid)`, `()`, `(AA)`
- ✅ Projects without tasks: `+project`
- ✅ Contexts without tasks: `@context`
- ✅ Key-value without tasks: `key:value`
- ✅ Colons in values: `url:http://site.com/path:8080`
- ✅ Spaces in keys: `long key:value`

**Expected Behavior**:
- Library-specific handling of invalid formats
- Comments filtered or preserved per specification
- Malformed entries handled gracefully
- No crashes or data corruption
- Consistent error handling

### 7. Project Names Edge Cases

**Purpose**: Ensure project name integrity (fix original bash issues)

**Test Cases**:
- ✅ Special characters: `+mobile-app`, `+web-2.0`, `+api_v2`
- ✅ Underscores: `+project_name`, `+team_alpha`
- ✅ Numbers: `+v2`, `+phase3`, `+2025-roadmap`
- ✅ Mixed case: `+WebApp`, `+iOSApp`, `+APIv2`

**Expected Behavior**:
- **CRITICAL**: No loss of `+` sign (original bash bug)
- All characters in project names preserved
- Case sensitivity maintained
- Special characters intact

### 8. Error Condition Tests

**Purpose**: Handle invalid inputs gracefully

**Test Cases**:
- ❌ Invalid date formats: `due:not-a-date`, `due:2025-13-45`
- ❌ Malformed tasks: Tasks that can't be parsed by library
- ❌ File permission issues: Read-only files, missing files
- ❌ Extremely large files: Memory/performance limits

**Expected Behavior**:
- Clear error messages for invalid dates
- Graceful failure with non-zero exit codes
- No data corruption on errors
- File system errors handled properly

### 9. Performance Tests

**Purpose**: Ensure acceptable performance at scale

**Test Cases**:
- ✅ Small files: 1-10 tasks
- ✅ Medium files: 100-1,000 tasks
- ✅ Large files: 10,000+ tasks
- ✅ Files with extensive metadata per task
- ✅ Mixed complexity scenarios

**Performance Targets**:
- Small files: <100ms
- Medium files: <1s
- Large files: <10s
- Memory usage: Reasonable for file size
- No memory leaks

### 10. Integration Tests

**Purpose**: Verify integration with todo.sh and environment

**Test Cases**:
- ✅ Environment variable support: `$TODO_FILE`, `$DONE_FILE`
- ✅ Command line arguments: `--dry-run`, `--verbose`, `--diff`
- ✅ Exit codes: 0 (no changes), 1 (error), 2 (dry-run with changes)
- ✅ File backup creation
- ✅ Atomic file operations
- ✅ todo.sh action integration

**Expected Behavior**:
- Proper environment variable handling
- Correct exit codes for different scenarios
- Backups created with timestamps
- Files updated atomically
- Seamless todo.sh integration

## Known Edge Cases and Limitations

### Library-Specific Behavior

The formatter uses `github.com/1set/todotxt` library, which has specific behaviors:

1. **Comment Filtering**: Comments (`# text`) are typically filtered out
2. **Date Validation**: Strict YYYY-MM-DD format required
3. **Priority Parsing**: Only single-letter priorities `(A)` through `(Z)`
4. **Completion Format**: Requires `x YYYY-MM-DD` format

### Metadata Ordering

The library may reorder metadata alphabetically. This is expected behavior:
- Input: `issue:ABC-123 priority:high assignee:dev`
- Output: `assignee:dev issue:ABC-123 priority:high`

### Special Character Handling

These characters are handled correctly in metadata values:
- URLs with parameters: `url:https://site.com?a=1&b=2`
- Email addresses: `email:user@domain.com`
- File paths: `path:/usr/local/bin/app`
- Percentages: `progress:75%`
- Version numbers: `version:1.2.3-beta+build.456`

### Error Conditions

Known error conditions that return exit code 1:
- Invalid date formats in metadata
- File permission issues
- Malformed todo.txt that can't be parsed

## Testing Commands

### Basic Test
```bash
./todotxtfmt --dry-run --diff --verbose testfile.txt
```

### Comprehensive Test Suite
```bash
./run_tests.sh
```

### Manual Verification
```bash
# Test with your todo file
export TODO_FILE=/path/to/your/todo.txt
todo.sh format --dry-run --verbose
```

## Regression Prevention

### Critical Behaviors to Maintain

1. **Project Name Integrity**: Must never lose `+` signs
2. **Metadata Preservation**: All `key:value` pairs preserved
3. **Special Character Support**: URLs, emails, paths intact
4. **Issue Tag Support**: All issue tracking formats work
5. **Performance**: Large files process in reasonable time

### Test Automation

The test suite should be run:
- Before any code changes
- After library updates
- Before releases
- On different operating systems

### Monitoring

Monitor for:
- Data corruption reports
- Performance degradation
- New edge cases from users
- Library compatibility issues

## Future Test Considerations

### Additional Scenarios to Test

1. **Unicode Support**: Tasks with emoji, international characters
2. **Very Large Metadata**: Tasks with dozens of key-value pairs
3. **Nested Projects**: Project hierarchies like `+project.subproject`
4. **Time-based Metadata**: Various timestamp formats
5. **Binary File Handling**: What happens with non-text files

### Platform-Specific Testing

- macOS (current primary target)
- Linux distributions
- Windows (if needed)
- Different terminal environments

This test plan ensures the formatter maintains robustness while handling the complexity of real-world todo.txt files.