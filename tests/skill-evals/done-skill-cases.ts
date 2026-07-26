export const DONE_ACTIONS = [
  "inspect_state",
  "commit_task_changes",
  "fetch_remote",
  "rebase_task",
  "fast_forward_default",
  "push_default",
  "verify_remote",
  "report_blocked",
  "request_user_cleanup",
  "preserve_unrelated_dirt",
  "defer_dirty_worktree_cleanup",
  "switch_canonical_branch",
  "create_preservation_branch",
  "stash_unrelated_dirt",
  "reset_unrelated_dirt",
  "commit_unrelated_dirt",
  "remove_dirty_worktree",
] as const;

export type DoneAction = (typeof DONE_ACTIONS)[number];

export type DoneDecision = {
  status: "blocked" | "continue";
  canonicalDefaultCheckout: "unchanged" | "updated";
  actions: DoneAction[];
  explanation: string;
};

export type DoneSkillEvalCase = {
  id: string;
  name: string;
  scenario: string;
  expected: {
    status: DoneDecision["status"];
    canonicalDefaultCheckout: DoneDecision["canonicalDefaultCheckout"];
    requiredActions: DoneAction[];
    forbiddenActions: DoneAction[];
  };
};

const canonicalMutations: DoneAction[] = [
  "fast_forward_default",
  "push_default",
  "switch_canonical_branch",
  "create_preservation_branch",
  "stash_unrelated_dirt",
  "reset_unrelated_dirt",
  "commit_unrelated_dirt",
];

export const DONE_SKILL_EVAL_CASES: DoneSkillEvalCase[] = [
  {
    id: "dirty-canonical-default",
    name: "blocks when canonical main has unrelated dirt",
    scenario: `
The task commit is complete and green in a clean feature worktree.
The actual default branch is main. main is checked out at /repo/canonical.
/repo/canonical has unrelated tracked edits and unrelated untracked files.
The user invoked $done but did not authorize moving, stashing, committing, or
resetting that unrelated work. Git cannot check out main in another worktree.
Decide the closeout outcome and actions.
`,
    expected: {
      status: "blocked",
      canonicalDefaultCheckout: "unchanged",
      requiredActions: ["preserve_unrelated_dirt", "report_blocked"],
      forbiddenActions: canonicalMutations,
    },
  },
  {
    id: "clean-canonical-default",
    name: "lands through a clean canonical main checkout",
    scenario: `
The task commit is complete and green in a clean feature worktree.
The actual default branch is main. main is checked out at /repo/canonical.
/repo/canonical is clean, the remote is writable, and repository policy permits
direct landing. Decide the closeout outcome and actions.
`,
    expected: {
      status: "continue",
      canonicalDefaultCheckout: "updated",
      requiredActions: ["fast_forward_default", "push_default", "verify_remote"],
      forbiddenActions: [
        "report_blocked",
        "switch_canonical_branch",
        "create_preservation_branch",
        "stash_unrelated_dirt",
        "reset_unrelated_dirt",
        "commit_unrelated_dirt",
      ],
    },
  },
  {
    id: "dirty-feature-clean-default",
    name: "lands committed task work but preserves a dirty feature worktree",
    scenario: `
The task commit is complete and green in a feature worktree. That feature
worktree also contains unrelated unstaged edits. The canonical main checkout is
clean, the remote is writable, and repository policy permits direct landing.
The unrelated edits must not be committed or deleted. Decide the closeout
outcome and actions.
`,
    expected: {
      status: "continue",
      canonicalDefaultCheckout: "updated",
      requiredActions: [
        "preserve_unrelated_dirt",
        "defer_dirty_worktree_cleanup",
        "fast_forward_default",
        "push_default",
        "verify_remote",
      ],
      forbiddenActions: [
        "report_blocked",
        "commit_unrelated_dirt",
        "remove_dirty_worktree",
        "stash_unrelated_dirt",
        "reset_unrelated_dirt",
      ],
    },
  },
];
