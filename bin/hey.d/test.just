# Test commands

import 'common.just'

# Run zunit tests for shell functions
ztest *args:
    #!/usr/bin/env bash
    cd "{{FLAKE_DIR}}"
    if ! command -v zunit &>/dev/null; then
        echo "zunit not found. Install with: brew install zunit-zsh/zunit/zunit"
        exit 1
    fi
    
    if [[ -n "{{args}}" ]]; then
        # Run specific test file(s)
        zunit {{args}}
    else
        # Run all .zunit tests
        find config -name '*.zunit' -exec zunit {} \;
    fi
