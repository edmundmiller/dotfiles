# Amoxide package

Package upstream `sassman/amoxide-rs` binaries `am` and `am-tui` from one
source/version and Cargo graph, using multiple outputs rather than duplicate
derivations. Keep `meta.mainProgram = "am"` so `nix run` selects the CLI.

Run `hey check packages/amoxide` and build the package after source, Cargo, output,
or wrapper changes. Smoke-test both binaries; `nix run` checks only the declared
main program.
