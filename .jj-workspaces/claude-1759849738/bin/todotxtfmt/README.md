# Todo.txt Formatter

A robust Go-based formatter for todo.txt files that properly handles metadata, issue tracking, and project names without corruption.

## Problem Solved

Replaces fragile bash/AWK-based formatters that were:
- ❌ Corrupting project names (`+fitness` → `fitness`)
- ❌ Losing metadata (`due:2025-01-15`, `issue:AUTH-123`)
- ❌ Breaking with complex regex patterns
- ❌ Unreliable with special characters

## Features

- ✅ **Robust parsing** using `github.com/1set/todotxt` library
- ✅ **Complete metadata preservation** - all `key:value` pairs maintained
- ✅ **Project name integrity** - no more losing `+` signs
- ✅ **Issue tracking support** - works with any `issue:TICKET-123` format
- ✅ **Special character handling** - URLs, emails, paths, percentages
- ✅ **todo.sh integration** - drop-in replacement with fallback
- ✅ **Atomic operations** - backup creation and safe file updates
- ✅ **Performance** - handles large files efficiently

## Installation

```bash
# Build the binary
go build -o todotxtfmt cmd/todotxtfmt/main.go

# Install to todo.sh actions directory
cp todotxtfmt ~/.todo.actions.d/

# The format action is automatically updated to use the Go binary
```

## Usage

### Via todo.sh (Recommended)
```bash
todo.sh format                    # Format $TODO_FILE
todo.sh format --dry-run          # Preview changes
todo.sh format --verbose          # Show detailed output
todo.sh format --help             # Show all options
```

### Direct Binary Usage
```bash
./todotxtfmt --help
./todotxtfmt --dry-run --diff --verbose todo.txt
./todotxtfmt todo.txt             # Format in place
```

## Modes

### Simple Mode
- Normalize priority placement and case
- Fix date formats (YYYY-MM-DD)
- Remove priorities from completed tasks
- Normalize spacing and metadata format
- Minimal repositioning

### Comprehensive Mode  
- All simple mode features
- Reposition @contexts and +projects to end
- Sort tags and metadata (configurable)
- Normalize date metadata values
- Add missing completion dates
- Full structural reorganization

## Why Go?

The original bash/AWK formatters had several issues:

1. **Regex Complexity**: Parsing todo.txt properly requires understanding context, which regex can't handle well
2. **Edge Cases**: Email addresses, URLs, and complex metadata often broke shell parsers
3. **Performance**: Large files (1000+ tasks) were slow to process
4. **Maintenance**: Complex AWK scripts are hard to debug and extend
5. **Reliability**: Shell parameter expansion and escaping issues caused data corruption

The Go implementation:
- Uses a proper parser that understands todo.txt semantics
- Handles Unicode, different encodings, and file formats correctly
- Is much faster for large files
- Provides better error handling and validation
- Is easier to test and maintain

## Testing

```bash
# Run tests
go test ./...

# Test with sample data
todotxtfmt --dry-run --diff testdata/sample.txt
```

## Example

Input:
```
(C)     Get a gym bag for my car @personal  +fitness    
Fix    critical    bug +webapp due:today
x (A) 2025-09-06 Fill 30 prescription due:2025-09-07 t:2025-09-07
```

Output (comprehensive mode):
```
(C) 2025-09-06 Get a gym bag for my car @personal +fitness
Fix critical bug +webapp due:2025-09-06
x 2025-09-06 Fill 30 prescription due:2025-09-07 t:2025-09-07
```

## Configuration

Environment variables:
- `TODO_FILE`: Default input file
- `TODOTXT_FORMAT_MODE`: Default mode (simple/comprehensive)

Command line flags:
- `--mode`: simple or comprehensive
- `--dry-run`: Preview changes only
- `--diff`: Show unified diff
- `--backup`: Create timestamped backups
- `--verbose`: Detailed output
- `--sort-tags`: Sort @contexts and +projects (none/alpha)
- `--sort-meta`: Sort metadata keys (none/alpha)

## Migration from Shell Formatters

The Go formatter is designed to be a drop-in replacement. The enhanced format action script automatically detects and prefers the Go binary when available, falling back to shell formatters if needed.

To migrate:

1. Install the Go binary
2. Replace your format action script
3. Test with `--dry-run` first
4. Optional: Remove old shell formatters once satisfied

## License

MIT License