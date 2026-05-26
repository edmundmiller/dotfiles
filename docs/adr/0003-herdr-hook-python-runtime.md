# ADR 0003: Herdr hook scripts use `uv` Python shebangs

## Status

Accepted

## Context

`bin/herdr-worktree-layout` runs as Herdr's `worktrees.post_create_command`. It is a lifecycle hook, not an interactive shell command, so its interpreter and dependencies must be available from the Herdr server environment. Other `bin/herdr-*` helpers also run from Herdr keybindings or agent tooling, so using the same launcher keeps behavior consistent across helpers.

The scripts are currently stdlib-only, but they perform enough JSON, socket, process, and argument orchestration that Python is much more maintainable than Bash. We considered several Python script launcher options:

- direct Python shebangs such as `#!/usr/bin/env python3`;
- Nix `nix-shell` shebangs such as `#!/usr/bin/env nix-shell` with `#! nix-shell -i python3 -p python3`;
- `cached-nix-shell` as a faster caching layer for `nix-shell`;
- `uv run --script` shebangs with PEP 723-style inline script metadata.

The uv documentation explicitly supports executable scripts with the shebang:

```python
#!/usr/bin/env -S uv run --script
```

It also supports declaring dependencies directly in that shebang script's inline metadata, and `uv add --script` can maintain those dependency entries. For reproducibility, uv can lock PEP 723 scripts with `uv lock --script`, producing an adjacent script lockfile, and inline metadata can include `[tool.uv].exclude-newer` to restrict resolution to distributions published before a chosen timestamp.

Nix documents `nix-shell -i` as the chained interpreter for shebang scripts, and the NixOS wiki documents the multi-line `nix-shell` shebang pattern. This is useful when the script's runtime must be provided by Nix. However, local benchmarking on macOS showed roughly:

| Launcher                                        | Mean startup |
| ----------------------------------------------- | -----------: |
| direct `python3`                                |        23 ms |
| `uv run --script`                               |        51 ms |
| current `herdr-worktree-layout --help` via `uv` |        68 ms |
| `nix-shell -i python3 -p python3`               |       947 ms |
| `cached-nix-shell`                              |      1051 ms |

`cached-nix-shell` did not improve this benchmark because it refreshed its cache on every temporary-script run. It may behave differently for stable scripts, but it remains another runtime dependency and was not clearly better here.

The key reason to prefer `uv` is not just speed: `uv` script metadata gives checked-in scripts a compact, ergonomic way to declare future Python package dependencies inline. That matters for Herdr hooks and similar agent helper scripts where we may eventually want a small dependency without converting the script into a full package.

## Decision

For checked-in Herdr helper scripts that benefit from Python and may need lightweight Python package dependencies, prefer a `uv run --script` shebang with inline script metadata.

Example:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
```

Keep scripts stdlib-only when practical, but keep the `uv` script format when future package declaration ergonomics are valuable. When a script gains dependencies, add them with `uv add --script` and commit the inline metadata. For scripts where reproducibility matters beyond normal uv caching, also commit the adjacent lockfile from `uv lock --script`; consider `[tool.uv].exclude-newer` when long-term replayability is more important than floating to the newest compatible release.

The Herdr module/package wiring must ensure `uv` is available in the environment that launches Herdr hooks. If that cannot be guaranteed for a target host, use a Nix-installed wrapper with an absolute interpreter path or a `nix-shell` shebang for that host-specific script.

## Consequences

- Herdr helper scripts start fast enough for interactive lifecycle hooks and keybindings while remaining easy to extend with Python dependencies.
- Hook scripts depend on `uv` being available to the Herdr server/hook environment; this must be handled declaratively by the module/profile rather than relying on an interactive shell.
- `nix-shell` shebangs remain appropriate when Nix-provided runtime purity matters more than startup latency or inline Python dependency ergonomics.
- `cached-nix-shell` remains a possible manual optimization, but it is not the default for this repo's Herdr hook scripts.

## References

- Nix 2.28 `nix-shell` manual: https://nix.dev/manual/nix/2.28/command-ref/nix-shell.html
- NixOS wiki: https://wiki.nixos.org/wiki/Nix-shell_shebang
- Travis B. Hartwell gist: https://gist.github.com/travisbhartwell/f972aab227306edfcfea
- uv script shebangs: https://docs.astral.sh/uv/guides/scripts/#using-a-shebang-to-create-an-executable-file
- uv script reproducibility: https://docs.astral.sh/uv/guides/scripts/#improving-reproducibility
- cached-nix-shell: https://github.com/xzfc/cached-nix-shell
