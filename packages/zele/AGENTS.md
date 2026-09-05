# Zele

Package `remorses/zele` upstream with ordered former-fork patches and a lockfile
for the patched tree. Keep OAuth client lookup and missing-browser handling.
Binary/rename deltas require Git-aware application, not ordinary unified patches.

`readonly-wrapper.sh` is the installed entrypoint: block sending, direct
replies/forwards, draft sends, live unsubscribe, and the send-capable TUI.
Reads, draft creation, and unsubscribe dry-runs remain available.

The Bun build needs explicit Prisma engines and sqlite to regenerate schema.
Preserve `CREATE TABLE IF NOT EXISTS`: the schema is reapplied each startup.
Ship `dist/`, `src/schema.sql`, and production dependencies, not the dev toolchain.
Wrapper regressions and `pkg-check zele` cover the package's special contracts.
