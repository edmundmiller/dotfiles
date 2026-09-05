# OpenCode tmux namer

Standalone native plugin in `src/index.ts`, built with `bun run build` and
packaged by Nix. The workstation OpenCode V2 module does not deploy V1 plugins;
do not copy its output into managed runtime paths or assume a rebuild enables it.

Direct session/permission events drive status; project/worktree context and
debounced intent signals drive naming. This is distinct from external tmux pane
content matching in tmux-opencode-integrated. Environment knobs and supported
events live in the implementation and README.
