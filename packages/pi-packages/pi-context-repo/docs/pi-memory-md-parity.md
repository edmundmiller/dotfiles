<!-- Purpose: Decision record for pi-memory-md UX parity choices in pi-context-repo. -->

# pi-memory-md UX parity decisions

Source reviewed: `VandeeFeng/pi-memory-md` README (tools/config section).

## Accepted now

### 1) Explicit `memory_list` tool

**Decision:** adopt.

**Why:** lower-friction discoverability. Agents can enumerate memory paths without scraping system prompt tree text.

### 2) Explicit `memory_read` tool

**Decision:** adopt.

**Why:** clear affordance for one-file retrieval; complements `memory_search` and improves deterministic workflows.

## Rejected (intentional)

### 3) `injection: message-append`

**Decision:** reject.

**Why:** pi-context-repo intentionally uses system-prompt injection every turn so pinned `system/` memory is always present and drift-detectable.

### 4) `tags`, `created`, `updated` frontmatter keys

**Decision:** reject.

**Why:** current schema is intentionally strict (`description`, `limit`, protected `read_only`) with pre-commit validation. Extra mutable metadata weakens consistency and increases churn.

### 5) `memory_refresh` command/tool

**Decision:** reject.

**Why:** memory view is rebuilt on each `before_agent_start` turn already. A manual refresh primitive is redundant in current architecture.

### 6) Multi-project shared storage layout under one root

**Decision:** reject (for now).

**Why:** this package stays repo-local by default (`<cwd>/.pi/memory`) with optional `PI_MEMORY_DIR` override for users who want centralized storage. Keep the default opinionated.

## Follow-ups

- Keep parity doc updated when new pi-memory-md features emerge.
- Revisit metadata fields only if a concrete workflow requires them and pre-commit semantics remain strong.
