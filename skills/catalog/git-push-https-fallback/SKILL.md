---
name: git-push-https-fallback
description: Push to GitHub over HTTPS with the GitHub CLI's stored login when a push over SSH fails because the SSH agent, such as 1Password, will not sign. Use when `git push` prints "sign_and_send_pubkey: signing failed", "agent refused operation" or "Permission denied (publickey)" for a GitHub remote.
---

# Git push HTTPS fallback

When an SSH push to GitHub fails because the agent will not sign, do not retry
SSH in a loop or wait on an approval prompt the user may not see. Push the same
commits over HTTPS with `gh`'s stored login, for this one command only:

```bash
git -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
  push https://github.com/<owner>/<repo>.git HEAD:refs/heads/<branch>
```

- The push must already be authorized; this changes the transport, not the
  approval. Confirm `gh auth status` shows the account that should push.
- Name the exact branch ref. Add `--force-with-lease` only when a force push
  was already authorized.
- Leave the remote URL and global git config alone. Do not run
  `gh auth setup-git`.
- Check the result: `gh api repos/<owner>/<repo>/branches/<branch> --jq .commit.sha`
  must equal `git rev-parse HEAD`. Pushing to a URL does not update the local
  `origin/<branch>` ref; run `git fetch` later if you need it.
- Commit signing is separate. This fallback only moves the push; if signing
  also fails, stop and tell the user.
- Say in your report that you used the fallback, so the user knows the SSH
  agent needs attention.
