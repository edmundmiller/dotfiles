# pi-review-box

`review-box` is the thin CLI bridge from ghui pull-request JSON to pi-herdr's shared Review Box flow.

```sh
gh pr view 216 --repo edmundmiller/dotfiles \
  --json number,headRefOid,headRefName,title,url |
  jq '. + {repository: "edmundmiller/dotfiles"}' |
  review-box
```

See [`docs/review-box.md`](../../../docs/review-box.md) for the input contract, state schema, resume behavior, and exit codes.
