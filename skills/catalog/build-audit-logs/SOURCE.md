# Source

Vendored from https://github.com/evloghq/evlog at commit
`c5dd007b9552048068f3dfc801a7625144554992`, directory
`skills/build-audit-logs`, including `references/framework-wiring.md`.
The upstream MIT license is in `LICENSE`.
Repository formatting is applied to Markdown and code examples.

Local safety deviation: the HTTP framework examples require a trusted
authentication proxy that strips client tenant headers, authenticates callers,
checks tenant membership, and injects the authorized tenant ID. The prerequisite
also blocks direct application access and appears beside each executable header
lookup. Without that proxy, use application-owned authenticated tenant resolution
with membership checks. Retain this deviation when refreshing upstream.

Reviewed every imported file. No scripts, executables, MCP servers, or activation
hooks are bundled. Shell searches are read-only. TypeScript examples configure
audit drains and may transmit sensitive events when implemented. Retention
deletion, signing-key rotation, tenant resolution, and remote storage require
application-specific policy and authorization. Do not trust an unvalidated
tenant header. Compliance tables are upstream guidance, not legal guarantees.
The examples use `Promise.all`; the upstream notes explain its failure-isolation
limits. API examples were not runtime-tested here.

Refresh from an explicit reviewed commit, copy both upstream files and the
license, review their contents, update this pin, and run the repository
skill-quality validator.

The catalog auto-enables this skill globally through existing Nix selection.
No installer, project-convention write, or host activation ran during vendoring.
