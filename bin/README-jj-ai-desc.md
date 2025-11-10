# jj-ai-desc - AI-Powered Commit Message Generator

An intelligent commit message generator for Jujutsu (jj) that uses Claude AI to create conventional commit messages.

## Files

- **`jj-ai-desc.ts`** - Main executable script
- **`jj-ai-desc-testable.ts`** - Exported functions for testing
- **`jj-ai-desc.test.ts`** - Comprehensive test suite (56 tests)

## Usage

```bash
# Basic usage - generate message for current commit
jj aid

# Generate and open editor
jj aide

# Generate for specific revision
jj ai-desc -r @-

# Direct script usage
./bin/jj-ai-desc.ts
./bin/jj-ai-desc.ts --edit
./bin/jj-ai-desc.ts --revision main
```

## jjui Integration

- `\a` - Generate AI commit message
- `\e` - Generate AI commit message and open editor

## Running Tests

```bash
# Run all tests
cd bin && bun test jj-ai-desc.test.ts

# Run with watch mode
cd bin && bun test --watch jj-ai-desc.test.ts

# Run specific test
cd bin && bun test jj-ai-desc.test.ts -t "stripMarkdownFences"
```

## Test Coverage

**56 comprehensive tests** covering:

### Unit Tests

- **Markdown fence stripping** (10 tests)

  - Various fence formats (with/without language identifiers)
  - Multiple fences, incomplete fences
  - Empty strings, whitespace handling

- **Argument parsing** (9 tests)

  - Flag variations (`--revision`, `-r`, `--edit`, `-e`, `--help`, `-h`)
  - Combined flags, missing values
  - Edge cases and malformed input

- **Conventional commit validation** (9 tests)
  - All conventional commit types: feat, fix, refactor, docs, test, chore, style, perf
  - Scope handling: `feat(api): message`
  - Breaking changes: `feat!: message`

### Integration Tests

- **Edge cases** (7 tests)

  - Long messages, special characters, unicode
  - Multi-line commits, code in commit body

- **Claude output handling** (5 tests)

  - Code fences with/without language
  - Extra whitespace, plain text output

- **Real-world scenarios** (4 tests)

  - Typical commit message flows
  - 72-character limit awareness

- **Error recovery** (3 tests)
  - Empty/whitespace output
  - Malformed markdown

## Features

✅ **Spinner with pipeline progress** - Shows 3 stages:

- Getting diff...
- Generating commit message...
- Applying commit message...

✅ **Markdown fence stripping** - Automatically removes ` ``` ` from Claude output

✅ **Conventional commits** - Generates proper conventional commit messages

✅ **Error handling** - Clear, colored error messages with suggestions

✅ **Fully tested** - 56 tests with 83 assertions

## Dependencies

- `nanospinner` - Lightweight spinner (auto-installed by Bun)
- Bun runtime
- Claude CLI (`~/.local/bin/claude`)
- Jujutsu (jj)

## Development

The code is split into two files for testability:

1. **`jj-ai-desc-testable.ts`** - Pure functions (exported for testing)

   - `stripMarkdownFences(text: string): string`
   - `parseArgs(argv: string[]): Args`

2. **`jj-ai-desc.ts`** - Main script (imports from testable)
   - Subprocess execution
   - Spinner management
   - User interaction

This separation allows comprehensive unit testing without mocking Bun.spawn() or the spinner.
