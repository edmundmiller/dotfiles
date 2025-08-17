# General Nix commands

import 'common.just'

# Run garbage collection
gc:
    nix-collect-garbage -d

# Open nix repl with flake loaded
repl:
    #!/usr/bin/env bash
    cd "{{FLAKE_DIR}}"
    tempfile="/tmp/dotfiles-repl.nix"
    echo "(builtins.getFlake \"{{FLAKE_DIR}}\")" > "$tempfile"
    nix repl '<nixpkgs>' "$tempfile"

# Search nixpkgs for packages
search query:
    nix search nixpkgs {{query}}

# Start shell with package available
shell package:
    nix shell nixpkgs#{{package}}