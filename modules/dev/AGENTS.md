# Dev — Language Toolchain Modules

Each file enables a language toolchain via `modules.dev.<lang>.enable`. Installs compilers, package managers, and sets up environment variables (XDG-compliant where possible).

## Files

| File           | Language/Toolchain | Notable Details                          |
| -------------- | ------------------ | ---------------------------------------- |
| `node.nix`     | Node.js            | fnm lazy-loading, bun global packages    |
| `python.nix`   | Python             | conda/mamba setup                        |
| `rust.nix`     | Rust               | rustup + cargo                           |
| `shell.nix`    | Shell scripting    | shellcheck, shfmt                        |
| `nixlang.nix`  | Nix                | nil LSP, nixfmt                          |
| `lua.nix`      | Lua                | LuaJIT, stylua                           |
| `julia.nix`    | Julia              | Julia language                           |
| `R.nix`        | R                  | R + RStudio                              |
| `scala.nix`    | Scala              | sbt, metals                              |
| `cc.nix`       | C/C++              | GCC, clang                               |
| `clojure.nix`  | Clojure            | Clojure + Leiningen                      |
| `common-lisp.nix` | Common Lisp     | SBCL                                     |
| `nextflow.nix` | Nextflow           | Bioinformatics workflow manager          |

## Pattern

```nix
modules.dev.<lang> = {
  enable = mkBoolOpt false;
  enableGlobally = mkBoolOpt false;  # some have this for PATH-level install
};
```

Enabled per-host in `hosts/<hostname>/default.nix`.
