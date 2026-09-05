# jjui

`config.toml` deploys to `~/.config/jjui/config.toml`; its custom commands depend
on aliases in `config/jj/config.toml`. Use `key_sequence` for multi-key commands
with the overlay UI; leader keys are deprecated. Commands use `args` for jj
subcommands or `lua` for scripting.

Lua uses `context.change_id()`, `context.file()`, and `context.checked_files()`.
Call `revisions.refresh()` after state-changing jj commands, `suspend()` before
external programs, and `flash()` for feedback. Config check: `jjui --check-config`.
