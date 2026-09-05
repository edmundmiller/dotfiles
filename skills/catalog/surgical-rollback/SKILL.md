---
name: surgical-rollback
description: Removes an offending or unauthorized delta while preserving valid and pre-existing work. Use when asked to undo an accidental implementation, revert only part of a change, or retain desired local work while reversing a commit.
---

# Surgical Rollback

Rollback follows provenance, not the size of the current diff.

## Before Mutation

Freeze further implementation. Identify the rollback the user authorized, the pre-change baseline, and protected artifacts. Obtain explicit authorization before creating a revert commit, rewriting history, or pushing shared state; approval for one action does not authorize the others.

## Method

1. Inspect current status, staged and unstaged diffs, and relevant commits. Classify the exact changes as offending, valid task work, pre-existing user work, or protected state.
2. Compare that classification with the pre-turn baseline. If provenance is uncertain, preserve the ambiguous work and ask a focused question rather than inferring that all dirty files belong to the accidental turn.
3. Choose the smallest rollback unit. Enumerate paths or hunks for uncommitted work, or identify the exact offending commit for an authorized revert. Mixed files require hunk-level preservation rather than whole-file restoration.
4. Remove or restore only the authorized offending delta. Preserve saved plans, unrelated dependency artifacts, accepted downstream logic, and pre-existing work.
5. If the user explicitly wants a committed change reverted but retained locally, save its exact patch first. Create and publish the revert only with the corresponding authorizations, then restore the desired patch unstaged if requested. If restoration conflicts, stop and preserve the patch rather than overwriting current work.
6. Stop at the rollback boundary. Verify the resulting state; do not silently resume the implementation that was rolled back.

## Verification

- Compare `git status --short` and both staged and unstaged diffs with the recorded baseline. An initially clean worktree should be clean again only when the rollback scope covers all new work.
- Confirm every protected artifact and retained change remains in its requested staged or unstaged form.
- For a narrowed code correction, run the relevant focused check. If it fails, preserve the narrowed delta, diagnose the failure, and report it without claiming completion.
- After an explicitly authorized publication, compare local state with the authoritative remote branch, not just a potentially stale tracking ref.
- Report exactly what was removed or reverted, what was retained, final status, and any verification limitation.

## Failure Modes

- **Whole-worktree reset:** use the pre-turn baseline and enumerated delta; a dirty file is not proof of agent ownership.
- **Revert loses desired local work:** preserve the exact patch before the authorized revert and verify its requested restoration afterward.
- **Contract correction removes valid downstream behavior:** remove only the incorrect fields or flow and check that accepted logic still works.

## Provenance

Forged by Lore from six beats in five native OMP sessions (2026-07-17 through 2026-09-01), theme `surgical-rollback-preserves-valid-work`. Evidence and dossier remain in the private local Lore corpus; transcript paths and project identities are intentionally omitted here.
