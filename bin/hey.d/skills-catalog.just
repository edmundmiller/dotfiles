# Skills catalog (child flake in ./skills)

# Update only skill-source pins (skills/flake.lock)
skills-update:
    cd {{FLAKE_DIR}}/skills && nix flake update

# Sync local/shared skills (refresh dotfiles pin + parent lock + rebuild)
skills-sync:
    cd {{FLAKE_DIR}}/skills && nix flake lock --update-input dotfiles-repo
    cd {{FLAKE_DIR}} && nix flake update skills-catalog
    just rebuild

# Update skill pins + rebuild host
skills-bump:
    cd {{FLAKE_DIR}}/skills && nix flake update
    just rebuild
