# Deferred autoresearch ideas

- Split `mini.nvim` into selectively loaded modules (e.g. `mini.ai`/`mini.surround` only, loaded on operator/key usage) instead of one `VeryLazy` block; likely needs custom key bootstrap to avoid UX regressions.
- Profile `VeryLazy` callback cost per plugin and migrate only highest-cost specs to command/key triggers with measured guardrails; prior full telescope key-trigger rewrite regressed, but targeted partial deferral may still win.
