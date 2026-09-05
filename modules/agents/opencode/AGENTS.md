# OpenCode V2 module

The module isolates managed config/core/agents/commands under
`~/.config/opencode2/opencode/` and owns the V2 compatibility alias
`~/.config/opencode`. V1 plugins are incompatible. Global instructions come
from `config/agents/core.md`, not an old rules glob; sources are in `config/opencode/`.

Shared skills use `~/.agents/skills`; targeted skills use the compatibility
alias. Plugin caches under `~/.cache/opencode` remain runtime-owned.

For confirmed plugin-cache corruption, the guarded repair is
`hey opencode-update`, followed by restart. A tarball 404 can instead indicate
registry propagation; check availability before clearing caches.
