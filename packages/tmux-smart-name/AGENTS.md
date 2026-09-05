# Tmux smart names

Zero-dependency TypeScript, Bun-bundled for Node. `process.ts` detects agent
binaries/aliases, `status.ts` reads pane status, and `naming.ts` builds names;
changing process recognition alone does not define status semantics.

`smart-name.sh` hooks use index `[0]`; `theme.conf` uses `[100]` to avoid
clobbering each other. Focused checks: `bun test` and
`bun build src/index.ts --outdir dist --target node`. Nix patches Node to its
store path in the shipped wrapper.
