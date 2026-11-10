# Task effect helpers

This hidden directory is excluded from mise task discovery. Its shell helpers
are invoked explicitly by native Bend controllers in `packages/hey/`; it is not
a second task implementation layer.

`wait-homebrew-idle.sh` performs the Homebrew process wait used by
`packages/hey/system-rebuild.bend`. Keep rebuild policy and sequencing in Bend.
Caller tests substitute a disposable wait helper, so do not remove that fixture
or let it wait on the developer's real processes.

Run `hey check bin/hey.d packages/hey` after changing a helper or its caller.
Host activation remains separately authorized. Do not add Nushell fallbacks or
another validation selector here.
