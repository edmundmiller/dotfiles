#!/bin/bash
# Install bashunit for testing

set -euo pipefail

BASHUNIT_VERSION="0.23.0"
INSTALL_DIR="$(pwd)/tests"

echo "Installing bashunit v${BASHUNIT_VERSION}..."

# Create tests directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Download bashunit
curl -fsSL https://github.com/typeddevs/bashunit/releases/download/v${BASHUNIT_VERSION}/bashunit \
    -o "$INSTALL_DIR/bashunit"

chmod +x "$INSTALL_DIR/bashunit"

echo "✅ bashunit installed to $INSTALL_DIR/bashunit"
echo ""
echo "Usage:"
echo "  ./tests/bashunit tests/"
echo "  ./tests/bashunit tests/test_*.sh"
