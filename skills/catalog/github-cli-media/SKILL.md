---
name: github-cli-media
description: Attach local images or videos to GitHub issues, pull requests, and comments with GitHub CLI's repeatable --attach flag. Use when publishing screenshots, recordings, diagrams, or rendered results from local files to GitHub.
---

# GitHub CLI Media

Use `--attach` on supported `gh issue` and `gh pr` commands for authorized
GitHub media uploads instead of committing the file or hosting it elsewhere.

Pair it with [agent-browser](https://agent-browser.dev/) when visual browser
evidence helps: capture local before-and-after screenshots or a recording, then
attach them in the same issue, pull request, or comment write.

## Guardrails

- Require `gh` v2.99.0 or newer and confirm the target command's help lists
  `--attach`. Otherwise, report the required managed upgrade instead of
  attempting an undocumented upload flow.
- Treat the upload as an external write. Drafting an issue, pull request, or
  comment does not authorize uploading its attachments.
- Confirm the account, repository, target item, and file contents immediately
  before the command. Uploads require `WRITE`, `MAINTAIN`, or `ADMIN` access.
- Use only on GitHub.com or GitHub Enterprise Cloud. GitHub Enterprise Server
  and GitHub App tokens are not supported.

## Attach

`--attach <path>` works on `gh issue create`, `gh issue edit`,
`gh issue comment`, `gh pr create`, `gh pr edit`, and `gh pr comment`.
Repeat the flag for multiple files:

```bash
gh issue comment 12 --repo OWNER/REPO --body 'Reproduction:' \
  --attach '/tmp/agent-browser-before.png#Before the change' \
  --attach '/tmp/agent-browser-after.png#After the change'
```

- A matching local path in the Markdown body is rewritten to the uploaded URL
  in place and keeps its existing alt text. Otherwise, attachments are appended
  in flag order.
- For an image, quote `<path>#<alt text>` so the shell does not treat `#` as a
  comment. The filename is the fallback alt text. Videos do not accept alt text.
- Supported extensions are PNG, JPG/JPEG, GIF, WebP, SVG, MP4, MOV, and WebM.
  One invocation accepts at most 50 attachments.
- Images and GIFs are limited to 10 MB. Video is limited to 10 MB on Free plans
  and 100 MB on paid plans.

Uploads stop at the first failure. Earlier files may still be attached while
the command exits nonzero, so re-read the user-visible body or comment before
retrying. After success, verify that referenced local paths were replaced or
unreferenced media was appended, and that it renders in the intended position.

Sources: [GitHub announcement](https://github.blog/changelog/2026-09-01-github-cli-media-in-issues-pull-requests-and-comments/),
[GitHub CLI docs](https://docs.github.com/en/github-cli/github-cli/attaching-files-with-github-cli),
and the [official `gh` skill](https://github.com/cli/cli/blob/v2.99.0/skills/gh/SKILL.md#attaching-images-and-videos).
