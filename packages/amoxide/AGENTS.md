# Amoxide Package

- Upstream repo: <https://github.com/sassman/amoxide-rs>
- Package both workspace binaries together from one source/version: `am` (CLI) and `am-tui` (TUI).
- Prefer multiple Nix outputs over separate package definitions when the binaries share the same upstream release and Cargo dependency graph.
- Keep `meta.mainProgram = "am"` on the combined package so `nix run` defaults to the CLI.
