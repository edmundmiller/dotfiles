# Packages

New packages use `<name>/default.nix`; existing single-file packages are migration
exceptions. `lib.my.mapModules` discovers them and flake outputs expose
`pkgs.my.*` per system (`x86_64-linux`, `aarch64-darwin`).

Cross-package Pi imports use workspace package names with `workspace:*`
dependencies; `bin/lint-ts-architecture` rejects relative cross-package imports.

`pkg-list` discovers optional harness metadata. `pkg-check <unit>` handles
fresh upstream checkout, patch application, and upstream tests. Use the
`nix-package-patching` skill for updates. Keep ordered plain patches beside
the package, matching `default.nix`, rather than large inline source rewrites.

Check ownership: AST rules in `ast-grep/rules/`, cross-file/path policy in root
tests/flake checks, implementation tests beside the tool, upstream checks in
the package harness. `hey check` routes repository policy and changed Pi/OMP
package typechecks/tests (including dependents). `pkg-check` still owns upstream
patch tests; package builds and host activation are distinct checks/actions.
