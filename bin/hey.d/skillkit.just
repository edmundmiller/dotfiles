# Skillkit patch/install helpers

# Reinstall or re-patch the global @crafter/skillkit install.
skillkit-sync:
    #!/usr/bin/env bash
    set -euo pipefail
    DOTFILES="{{FLAKE_DIR}}" "{{FLAKE_DIR}}/bin/skillkit-sync"
