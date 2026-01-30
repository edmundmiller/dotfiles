# Hosts Configuration

Agent-facing documentation for host configurations.

## Critical Rules

### Do NOT Change Usernames

Each host has a fixed username that CANNOT be changed:

| Host            | Username       | Why                                      |
| --------------- | -------------- | ---------------------------------------- |
| mactraitorpro   | `emiller`      | Personal laptop, short username          |
| seqeratop       | `edmundmiller` | Work laptop, corporate naming convention |

**Never suggest unifying usernames across hosts.** The usernames are set by the machine's original setup and changing them breaks:
- Home directory paths
- File permissions
- agenix secret decryption paths
- Various hardcoded references

### Agenix Secrets

Secrets are encrypted per-host SSH key. If a secret isn't decrypting correctly:

1. Check `hosts/shared/secrets/secrets.nix` for which hosts have access
2. Re-encrypt with `agenix -e <secret>.age` (must have a key that can decrypt)
3. Rebuild on the target host to get the new decrypted version

Stale decrypted secrets can occur if the `.age` file was updated but the host hasn't rebuilt.

## Host Overview

### mactraitorpro (Personal Mac)
- User: `emiller`
- Primary development machine
- Full homebrew package set

### seqeratop (Work Mac)
- User: `edmundmiller`
- Work-focused packages
- 1Password enabled (work SSO)

### nuc (NixOS Server)
- User: `emiller`
- Remote deployment via `hey nuc`
- Services: docker, jellyfin, home-assistant, etc.
