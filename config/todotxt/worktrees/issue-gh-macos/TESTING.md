# Testing Guide

This project uses [bashunit](https://bashunit.typeddevs.com/) for modern, comprehensive testing of todo.txt actions.

## Quick Start

```bash
# Run all tests
./run_tests.sh

# Run specific test file
./tests/bashunit tests/test_open_action.sh

# Run with verbose output
./run_tests.sh --verbose
```

## Test Structure

### `test_open_action.sh`
Tests for the `open` action covering:
- GitHub shorthand parsing (`gh:owner/repo#123`)
- Jira token parsing (`jira:PROJ-123`)
- Multiple URL handling
- Edge cases and error conditions
- Interactive Jira setup
- URL validation

### `test_issue_action.sh`
Tests for the `issue` action covering:
- GitHub CLI integration with fallback
- macOS/Linux compatibility
- Issue opening, closing, and sync
- Token format support (both `gh:` and `issue:`)
- Error handling
- Cross-platform notifications

## Features

### Mocking & Spies
Tests use bashunit's built-in mocking system:
- Mock external commands (`gh`, `osascript`, `curl`)
- Spy on function calls to verify behavior
- Simulate different environments (macOS/Linux)
- Test authentication scenarios

### Coverage Areas
- ✅ URL parsing and validation
- ✅ Error handling and edge cases
- ✅ Cross-platform compatibility
- ✅ GitHub CLI integration
- ✅ Fallback mechanisms
- ✅ Notification systems
- ✅ File I/O operations

## Continuous Integration

### GitHub Actions Example
```yaml
name: Test todo.txt Actions
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Tests
        run: |
          chmod +x install_bashunit.sh run_tests.sh
          ./install_bashunit.sh
          ./run_tests.sh
```

### Local Development
```bash
# Install bashunit
./install_bashunit.sh

# Run tests on file changes (using entr)
find . -name "*.sh" | entr -c ./run_tests.sh

# Run specific test pattern
./tests/bashunit tests/test_*_action.sh
```

## Test Philosophy

1. **Comprehensive Coverage**: Test both success and failure paths
2. **Isolation**: Use mocks to avoid external dependencies  
3. **Cross-Platform**: Validate macOS and Linux compatibility
4. **Regression Prevention**: Catch spec violations early
5. **Documentation**: Tests serve as usage examples

## Adding Tests

### For new actions:
1. Create `tests/test_<action>_action.sh`
2. Follow existing patterns with `set_up()` and `tear_down()`
3. Use descriptive test names: `test_action_specific_scenario`
4. Mock external dependencies
5. Test both success and error cases

### For new features:
1. Add test cases to existing files
2. Update `run_tests.sh` if needed
3. Document expected behavior
4. Consider cross-platform implications

## Debugging Tests

```bash
# Run single test with debug output
./tests/bashunit --debug tests/test_open_action.sh

# Run specific test function
./tests/bashunit -f "test_open_github_shorthand" tests/test_open_action.sh

# Assert standalone for debugging
./tests/bashunit -a contains "expected" "$(./open 1 2>&1)"
```
