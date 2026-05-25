# QMD Onboarding Flow

## Goal

Create a stable QMD binding for the current repository without asking the model to invent the repo structure from scratch.

## Steps

1. **Scan** the repo
   - bounded traversal
   - markdown count
   - key files
   - top-level directory summaries
   - sample markdown paths

2. **Draft** a proposal deterministically
   - root = normalized repo root
   - collection key = path-derived encoding
   - glob = `**/*.md`
   - path contexts from folder heuristics

3. **Prompt** the agent with the draft
   - refine, don’t reinvent
   - ask the user for confirmation
   - do not call `qmd_init` yet

4. **Normalize** the confirmed proposal
   - root must match the current repo root
   - paths must stay repo-relative
   - duplicates collapse deterministically
   - annotations must be non-empty

5. **Execute** the init
   - add collection
   - set contexts
   - update that collection only
   - embed only if needed
   - write `.pi/qmd.json`

## v1 caveat

`qmd_init` activation uses `pi.setActiveTools()`, which is shared mutable session state.
QMD only adds/removes its own tool and does not try to coordinate global modal tool state.
