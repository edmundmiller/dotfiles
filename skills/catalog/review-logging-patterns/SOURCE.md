# Source

Vendored from https://github.com/evloghq/evlog at commit
`c5dd007b9552048068f3dfc801a7625144554992`, directory
`skills/review-logging-patterns`. The upstream MIT license is in `LICENSE`.

The upstream 1,301-line entrypoint lives in `references/logging-guide.md`.
Its relative Markdown link targets changed after the move, and repository
formatting is applied throughout. The local
`SKILL.md` routes to that guide and the upstream references,
and adds installation, scope, and sensitive-data boundaries.

Local safety deviation: the Next.js client-ingest example validates an explicit
timestamp/level/action allowlist, replaces free-text messages with `[REDACTED]`,
and drops all other client fields instead of logging the arbitrary body remainder.
The adjacent guidance treats client input as untrusted and calls out authentication,
body-size limits, and rate limits. Retain this deviation when refreshing upstream.

Reviewed every imported file. No scripts, executable files, MCP servers, or
activation hooks are bundled. Commands and TypeScript snippets are guidance,
not code executed during import. CLI examples can fetch unpinned packages,
`init` can change application files, `agents` can write instructions and install
skills, and remote drains transmit logs. These require the caller's authority.
Redaction examples include opt-outs, which are examples rather than defaults
to apply. Upstream API examples were not runtime-tested here.

Refresh from an explicit reviewed commit, retain the license and all references,
repeat the entrypoint move and relative-link adjustment, and update this pin.
Run the repository skill-quality validator on all three evlog skills.

These catalog skills auto-enable globally through the existing Nix selection.
Vendoring did not install packages, run `npx skills` or `evlog agents`, write
project conventions, or activate a host. Host activation remains a separate step.
