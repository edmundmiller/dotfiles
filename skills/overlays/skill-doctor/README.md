---
purpose: Extend the pinned upstream skill-doctor with Pi session collection.
applies_to: Updating skill-doctor or its local Pi compatibility patch.
entrypoint: Apply pi-support.patch to the pinned common-skills skill directory.
verification: Run the overlaid skill's Python unit tests and rebuild the skills catalog.
update_when: Upstream skill-doctor or Pi's session JSONL format changes.
---

# Skill-doctor Pi overlay

`skills/flake.nix` applies `pi-support.patch` to the hash-pinned
`warpdotdev/common-skills` input. Keep upstream files out of this repository;
refresh the patch against the new pinned revision when it no longer applies.

The overlay adds Pi as a collector source, follows the active session-tree
branch, detects Pi tool calls and skill envelopes, and discovers Pi-specific
skill directories.
