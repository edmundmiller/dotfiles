# gh-dash keybindings

Go-template variables depend on context:

- PRs: `.RepoName`, `.RepoPath`, `.PrNumber`, `.HeadRefName`.
- Issues: `.RepoName`, `.RepoPath`, `.IssueNumber`.

There is no `.Url` variable or `builtin: "open"`. Use a custom command with a
quoted URL, for example `open 'https://github.com/{{.RepoName}}/pull/{{.PrNumber}}'`.
Issue URLs use `/issues/{{.IssueNumber}}`.

[Keybinding reference](https://gh-dash.dev/configuration/keybindings).
