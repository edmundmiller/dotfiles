// Mock jj command responses for testing
// Based on actual jj 0.35.0 output format

export const mockResponses = {
  split: {
    success: `Rebased 1 descendant commits
First part: qpvuntsm 3a4b5c6d feat(opencode): add jj tools
Second part: rlvkpnzs 7e8f9a0b (no description set)`,
    noChanges: `Error: No changes to split off`,
  },

  jj_new: {
    success: `Working copy now at: kkmpptxz 1a2b3c4d (empty) (no description set)
Parent commit      : qpvuntsm 5e6f7a8b feat: existing commit`,
    withMessage: `Working copy now at: kkmpptxz 1a2b3c4d (empty) WIP: new feature
Parent commit      : qpvuntsm 5e6f7a8b feat: existing commit`,
    withNoEdit: `Created new commit: kkmpptxz 1a2b3c4d (empty) (no description set)`,
  },

  squash: {
    success: `Rebased 1 descendant commits
Working copy now at: qpvuntsm 9a0b1c2d feat: combined changes`,
    withMessage: `Working copy now at: qpvuntsm 9a0b1c2d feat: specified message`,
    abandoned: `Rebased 1 descendant commits
Abandoned commit qpvuntsm 3a4b5c6d (empty) (no description set)
Working copy now at: rlvkpnzs 7e8f9a0b feat: parent commit`,
  },

  describe: {
    success: `Working copy now at: qpvuntsm 1a2b3c4d feat: new description`,
    multipleRevisions: `Updated 2 commits`,
  },

  bookmark_set: {
    success: `Created bookmark main pointing to qpvuntsm 1a2b3c4d`,
    updated: `Moved bookmark main from rlvkpnzs to qpvuntsm`,
    backwards: `Moved bookmark main backwards from qpvuntsm to rlvkpnzs`,
  },

  status: {
    withChanges: `Working copy changes:
M config/opencode/tool/jj.ts
A config/opencode/tool/jj.test.ts
Working copy  (@) : qpvuntsm 1a2b3c4d (no description set)
Parent commit (@-): rlvkpnzs 5e6f7a8b main | feat: previous commit`,
    noChanges: `The working copy is clean
Working copy  (@) : qpvuntsm 1a2b3c4d feat: clean commit
Parent commit (@-): rlvkpnzs 5e6f7a8b main | feat: previous commit`,
    withConflicts: `Working copy changes:
M config/opencode/tool/jj.ts
There are unresolved conflicts at these paths:
config/opencode/tool/jj.ts    2-sided conflict
Working copy  (@) : qpvuntsm 1a2b3c4d (conflict) (no description set)
Parent commit (@-): rlvkpnzs 5e6f7a8b main | feat: previous commit`,
  },

  log: {
    default: `@  qpvuntsm emiller@example.com 2024-12-24 10:00:00 1a2b3c4d
│  (no description set)
◉  rlvkpnzs emiller@example.com 2024-12-24 09:00:00 main 5e6f7a8b
│  feat: previous commit
◆  zzzzzzzz root() 00000000`,
    withLimit: `@  qpvuntsm emiller@example.com 2024-12-24 10:00:00 1a2b3c4d
│  (no description set)
~`,
    withPatch: `@  qpvuntsm emiller@example.com 2024-12-24 10:00:00 1a2b3c4d
│  (no description set)
│  diff --git a/file.ts b/file.ts
│  --- a/file.ts
│  +++ b/file.ts
│  @@ -1,1 +1,2 @@
│   existing line
│  +new line`,
    noGraph: `qpvuntsm emiller@example.com 2024-12-24 10:00:00 1a2b3c4d
(no description set)
rlvkpnzs emiller@example.com 2024-12-24 09:00:00 main 5e6f7a8b
feat: previous commit`,
  },

  edit: {
    success: `Working copy now at: rlvkpnzs 5e6f7a8b feat: editing this commit
Parent commit      : zzzzzzzz 00000000 (empty) (no description set)`,
    alreadyEditing: `Already editing this commit`,
  },

  errors: {
    notInRepo: `Error: There is no jj repo in "."`,
    revisionNotFound: `Error: Revision "nonexistent" doesn't exist`,
    immutableCommit: `Error: Commit rlvkpnzs is immutable`,
    commandFailed: `Error: Command failed with exit code 1`,
  },
}

// Helper to add whitespace for testing trim behavior
export const withWhitespace = (response: string): string => {
  return `\n  ${response}  \n`
}
