---
purpose: Define where durable OMP module notes live and how agents should maintain them.
applies_to: Recording OMP behavior missing or ambiguous in upstream documentation.
entrypoint: Search purpose and applies_to in the first seven lines of files in this directory.
verification: Check each note's source claims, live commands, local links, and YAML summary.
update_when: The OMP documentation boundary or note-writing conventions change.
---

# OMP module notes

Use this directory for durable, verified notes that fill gaps in OMP's upstream documentation or explain this repository's OMP deployment. Keep transient task progress in `.agents/worklogs`, not here.

For each note:

- Cover one behavior or operating concern.
- Name the authoritative source and a live verification command when facts can drift.
- Mark version-specific runtime behavior and when it must be rechecked.
- Start with the five-field YAML summary above so agents can find the right note without reading every file.
- Update the note with the config or module behavior it describes.

Prefer correcting upstream or canonical configuration comments when that is the real source of truth. Add a local note when upstream is missing operational detail, behavior spans several sources, or this repository intentionally composes OMP differently.
