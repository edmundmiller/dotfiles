# oxlint-plugin-jev

Opt-in Jev and diff review, isolated from ordinary repository lint. Keep `oxlint`
and `@oxlint/plugins` on the same exact version in `package.json`. Refresh
`package-lock.json` with `npm install --install-links --ignore-scripts` in this directory. Edit
`rules.json` for the local questions. The fork's built files and exact source
commit belong in `vendor/oxlint-plugin-jev`; rebuild upstream rather than editing
`dist`. Do not put credentials in Nix or enable semantic checks in hooks or CI. Docs:
[oxlint](../../docs/agents/oxlint.md).
