# Todo.txt Open Action

A todo.txt-cli action that parses key-value pairs in todo items and opens corresponding links in your browser.

## Features

- **GitHub Integration**: `gh:owner/repo#123` → opens GitHub issue
- **Jira Integration**: `jira:TICKET-123` → opens Jira ticket
- **Multiple Links**: Opens all found links simultaneously
- **Flexible Configuration**: Multiple ways to configure Jira base URL

## Usage

```bash
todo.sh open ITEM#
```

Where `ITEM#` is the number of the todo item containing links.

### Examples

```bash
# Add todo items with links
todo.sh add "Fix bug gh:nf-core/modules#2230 and track in jira:SD-456"
todo.sh add "Review PR gh:user/awesome-project#42"

# Open links
todo.sh open 1    # Opens both GitHub issue and Jira ticket
todo.sh open 2    # Opens GitHub PR
```

## Supported Link Formats

### GitHub

- Format: `gh:owner/repo#123`
- Example: `gh:nf-core/modules#2230`
- Opens: `https://github.com/nf-core/modules/issues/2230`

### Jira

- Format: `jira:TICKET-123`
- Example: `jira:SD-456`
- Opens: `https://your-jira-base/browse/SD-456`

## Configuration

### Jira Base URL

The Jira base URL can be configured in several ways (in order of precedence):

1. **Environment Variable** (recommended):

   ```bash
   export JIRA_BASE_URL="company.atlassian.net"
   ```

2. **Todo directory config file**:

   ```bash
   echo "company.atlassian.net" > "$TODO_DIR/.jira_base_url"
   ```

3. **Interactive prompt**: If no configuration is found and you run `open` on a Jira token interactively, the script will prompt you and save the setting.

### URL Normalization

- Bare hostnames are automatically prefixed with `https://`
- `http://` URLs are preserved as-is
- Trailing slashes and other characters are handled gracefully

## Examples in Practice

```bash
# Set up Jira configuration
export JIRA_BASE_URL="mycompany.atlassian.net"

# Add some todos with links
todo.sh add "Investigate performance issue gh:myorg/backend#1234"
todo.sh add "Document API changes jira:DOC-567 and gh:myorg/api#89"
todo.sh add "Regular todo without links +project @context"

# Open links (assuming the items above are numbered 1, 2, 3)
todo.sh open 1    # Opens: https://github.com/myorg/backend/issues/1234
todo.sh open 2    # Opens: https://mycompany.atlassian.net/browse/DOC-567
                  #     AND https://github.com/myorg/api/issues/89
todo.sh open 3    # Reports: "No supported links found in item 3"
```

## Error Handling

- **Missing item**: Reports error and exits with code 1
- **Invalid item number**: Reports error and exits with code 1
- **No links found**: Reports message and exits with code 2
- **Missing Jira config**: Warns user but still opens any GitHub links found

## Testing

A comprehensive test suite is included in the `tests/` directory:

```bash
# Run all tests
./tests/run_all_tests.sh

# Run individual test suites
./tests/test_url_parsing.sh       # Unit tests for URL parsing
./tests/test_integration.sh       # Integration tests
./tests/test_edge_cases.sh        # Error handling and edge cases
```

The test framework includes:

- URL parsing validation
- End-to-end integration testing with mock browser opening
- Error condition testing
- Edge case validation
- Configuration testing

## Installation

The action is already installed at `/Users/emiller/.todo.actions.d/open` and should be automatically discovered by todo.txt-cli.

To verify installation:

```bash
todo.sh open usage
```

## Technical Details

- **Language**: Bash (compatible with macOS default Bash)
- **Dependencies**: None beyond standard Unix tools (grep, sed, awk)
- **Browser Integration**: Uses macOS `open` command
- **Exit Codes**:
  - 0: Success (links opened)
  - 1: Error (invalid input, missing item, etc.)
  - 2: No supported links found in item

## Future Enhancements

The script is designed to be easily extensible. To add support for new link types:

1. Add regex pattern for parsing
2. Add URL builder for the new service
3. Add corresponding tests

Example patterns that could be added:

- Pull requests: `pr:owner/repo#123`
- Direct URLs: `url:https://example.com`
- Internal tickets: `ticket:ABC-123`
