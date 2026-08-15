export const DONE_ACTIONS = [
  "inspect_state",
  "commit_task_changes",
  "fetch_remote",
  "rebase_task",
  "classify_explicit_task_commits",
  "skip_landed_task_equivalents",
  "replay_later_local_commits",
  "fast_forward_default",
  "push_default",
  "verify_remote",
  "report_blocked",
  "request_publication_authority",
  "create_or_update_pr",
  "wait_for_pr_gates",
  "checkpoint_partial",
  "verify_aggregate_patch",
  "request_user_cleanup",
  "preserve_unrelated_dirt",
  "verify_unrelated_dirt",
  "defer_dirty_worktree_cleanup",
  "switch_canonical_branch",
  "create_preservation_branch",
  "stash_unrelated_dirt",
  "reset_unrelated_dirt",
  "commit_unrelated_dirt",
  "remove_dirty_worktree",
  "force_push",
  "bypass_hooks",
] as const;

export type DoneAction = (typeof DONE_ACTIONS)[number];

export type DoneDecision = {
  status: "blocked" | "continue";
  outcome:
    | "done"
    | "done_local"
    | "landed_cleanup_deferred"
    | "pr_merge_pending"
    | "local_only"
    | "blocked";
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
    outcome: DoneDecision["outcome"];
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
    name: "lands when canonical main dirt does not overlap",
    scenario: `
The task commit is complete and green in a clean feature worktree.
The actual default branch is main. main is checked out at /repo/canonical.
/repo/canonical has unrelated tracked edits and unrelated untracked files.
The task changes do not overlap those dirty paths. Repository policy permits
direct landing. Git can integrate the explicit task commits in a temporary
detached worktree, then safely fast-forward /repo/canonical without touching
its unrelated dirt. Decide the closeout outcome and actions.
`,
    expected: {
      status: "continue",
      outcome: "done",
      canonicalDefaultCheckout: "updated",
      requiredActions: [
        "preserve_unrelated_dirt",
        "fast_forward_default",
        "push_default",
        "verify_remote",
      ],
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
    id: "concurrent-remote-advance-with-later-local-commit",
    name: "blocks unrelated later local work without publication authority",
    scenario: `
The task started from main at A and explicitly produced task commits T1 and T2.
Before closeout, another agent advanced origin/main with newer commits and
corrected patch-equivalent versions of T1 and T2. A separate local-only commit
H was then added after the old task commits, so local main is A-T1-T2-H while
origin/main has advanced on a different line. The default checkout also has
unrelated dirty agent-rule files which do not overlap H. Repository policy
permits direct landing and the remote is writable, but the user authorized only
T1 and T2. Decide the closeout outcome and actions without publishing H.
`,
    expected: {
      status: "blocked",
      outcome: "blocked",
      canonicalDefaultCheckout: "unchanged",
      requiredActions: [
        "classify_explicit_task_commits",
        "skip_landed_task_equivalents",
        "report_blocked",
      ],
      forbiddenActions: [
        "rebase_task",
        "replay_later_local_commits",
        "push_default",
        "commit_unrelated_dirt",
        "stash_unrelated_dirt",
        "reset_unrelated_dirt",
        "force_push",
        "bypass_hooks",
      ],
    },
  },
  {
    id: "overlapping-dirty-canonical-default",
    name: "blocks when canonical main dirt overlaps task changes",
    scenario: `
The task commit is complete and green in a clean feature worktree.
The actual default branch is main. main is checked out at /repo/canonical.
/repo/canonical has an uncommitted edit to the same file changed by the task.
Git's fast-forward preflight refuses because it would overwrite that work.
The user did not authorize moving, stashing, committing, or resetting it.
Decide the closeout outcome and actions.
`,
    expected: {
      status: "blocked",
      outcome: "blocked",
      canonicalDefaultCheckout: "unchanged",
      requiredActions: ["preserve_unrelated_dirt", "report_blocked"],
      forbiddenActions: [
        "push_default",
        "switch_canonical_branch",
        "create_preservation_branch",
        "stash_unrelated_dirt",
        "reset_unrelated_dirt",
        "commit_unrelated_dirt",
      ],
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
      outcome: "done",
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
      outcome: "landed_cleanup_deferred",
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
  {
    id: "required-pr-pending-approval",
    name: "checkpoints a required PR whose approval remains pending",
    scenario: `
Repository policy requires a GitHub pull request. The active GitHub account,
organization, repository, base, and task-owned head branch are verified. The
PR exists, all checks passed, but a required independent approval is still
missing after the 15-minute wait budget. Auto-merge was not authorized. Decide
the closeout outcome and actions.
`,
    expected: {
      status: "continue",
      outcome: "pr_merge_pending",
      canonicalDefaultCheckout: "unchanged",
      requiredActions: ["wait_for_pr_gates", "checkpoint_partial"],
      forbiddenActions: ["push_default", "fast_forward_default", "force_push", "bypass_hooks"],
    },
  },
];
