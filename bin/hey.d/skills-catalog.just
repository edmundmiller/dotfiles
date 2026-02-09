# Skills catalog (child flake in ./skills)

# Update only skill-source pins (skills/flake.lock)
skills-update:
    cd {{FLAKE_DIR}}/skills && nix flake update

# Update skill pins + rebuild host
skills-bump:
    cd {{FLAKE_DIR}}/skills && nix flake update
    cd {{FLAKE_DIR}} && just --justfile {{justfile()}} rebuild
