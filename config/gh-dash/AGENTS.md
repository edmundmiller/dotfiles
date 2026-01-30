# gh-dash Configuration

## Keybinding Template Variables

Custom keybinding commands use Go templates. Available variables differ by context:

**PRs:**
- `{{.RepoName}}` - owner/repo
- `{{.RepoPath}}` - local path
- `{{.PrNumber}}` - PR number
- `{{.HeadRefName}}` - branch name

**Issues:**
- `{{.RepoName}}` - owner/repo
- `{{.RepoPath}}` - local path
- `{{.IssueNumber}}` - issue number

**There is no `{{.Url}}` variable.** Construct URLs manually:
```yaml
# PR
command: "open 'https://github.com/{{.RepoName}}/pull/{{.PrNumber}}'"

# Issue
command: "open 'https://github.com/{{.RepoName}}/issues/{{.IssueNumber}}'"
```

## Common Gotchas

1. `builtin: "open"` does not exist - use custom `command` instead
2. Template variables must match context (PR vs Issue)
3. Quote URLs in commands to handle special characters

## Docs

- https://gh-dash.dev/configuration/keybindings
