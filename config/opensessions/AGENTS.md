# Opensessions plugins

With `modules.shell.tmux.opensessions.enable`, the tmux module links local
plugins to `~/.config/opensessions/plugins/`. The loader uses `require`, so
plugins use CommonJS and Node/Bun built-ins only. Pi support is upstream-native.

`plugins/hunk.js` polls `http://127.0.0.1:47657/session-api`, maps sessions through
`ctx.resolveSession`, emits `running` while present and `done` after disappearance.
It also marks tracked sessions done when the daemon becomes unreachable.
