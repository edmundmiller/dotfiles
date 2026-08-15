---
purpose: Land explicit jj changes while preserving other workspaces and bookmarks.
applies_to: Done closeout when jj root detection succeeds.
entrypoint: Snapshot the current workspace and stable task change IDs.
verification: verify-jj-landing.sh against local, tracked, and authoritative tips.
update_when: jj workspace, bookmark, signing, or publication behavior changes.
---

# jj closeout

`@` is workspace-local. Workspaces share the repository and operation log, not
the same working-copy commit. Never use repository-wide `jj undo` or
`jj op restore` as routine concurrent recovery.

1. Record `jj root`, `jj workspace root`, `jj workspace list`, `jj status`, the
   latest operation, remotes, `trunk()`, the stable task change IDs, and each
   cleanup candidate's workspace name and physical root.
2. Resolve task conflicts, describe meaningful changes, run repository gates
   plus focused tests, and create an empty successor with `jj new`. Do not
   assume every `@-` belongs to this task.
3. Run `jj git fetch --remote "$remote"`. If the remote advanced, rebase only
   the explicit task change range and rerun affected checks.
4. Move the actual default bookmark only after proving the task range:

   ```bash
   jj bookmark set "$default_bookmark" -r "$task_change_id"
   ```

5. Publish through jj, never raw `git push` or `jj_vcs align_push`:

   ```bash
   jj git push --remote "$remote" --bookmark "$default_bookmark"
   jj git fetch --remote "$remote"
   ```

6. Prove by stable change ID because signing may rewrite commit IDs:

   ```bash
   bash "${HOME}/.agents/skills/done/scripts/verify-jj-landing.sh" \
     "$task_change_id" "$default_bookmark" "$remote"
   ```

The verifier requires no task conflict, containment by the local default
bookmark, and equality among local, tracked-remote, and authoritative Git tips.
Retry one conflict-free remote race; a second race is `Blocked`.
