# Config sources

This directory owns dotfile content; `modules/` owns deployment through
`home.configFile` / `home.file`. `configDir` is `dotfiles.configDir` from
`modules/options.nix`. Most deployed files are read-only store symlinks;
activation uses `hey re` when requested.

Tool shell integration belongs in `config/<tool>/env.zsh` (environment/PATH)
or `aliases.zsh` (interactive setup), discovered by the zsh module. Writable
bootstrap exceptions, including Claude and Herdr, are documented in their scope.

- Pass raw values to subprocess argv APIs; use shell or Ex escaping only when constructing text for that parser. For example, `vim.fn.system` list arguments do not need `fnameescape`.
- Validate fields consumed from external JSON; a TypeScript cast is not validation. Preserve intentional fail-open behavior for optional widgets, but distinguish malformed state from legitimate empty state before a destructive or authorization decision. When replacing owned state, retain atomic writes and cleanup rather than shortening them to direct writes.

Validate source changes with `hey check config/<tool>` and include the owning
module path when deployment wiring changed. A source check does not prove that a
writable bootstrap or live application has adopted the new value.
