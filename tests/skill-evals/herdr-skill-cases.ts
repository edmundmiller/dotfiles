/**
 * Held-out task set for the herdr skill arm comparison.
 *
 * IMPORTANT: these tasks are written from a *taxonomy* derived from session
 * traces, never copied from a trace. The current skill's "Known pitfalls"
 * section was authored directly from those traces, so scoring it on them would
 * measure memorization rather than generalization.
 */

/** Commands agents have historically invented. Emitting one is a hard failure. */
export const HALLUCINATED_COMMANDS = [
  "herdr agents",
  "herdr agent status",
  "herdr agent send ",
  "herdr pane stop",
  "herdr worktree sessions",
  "herdr wait ",
  "herdr layout ",
] as const;

/** Flags/paths removed or never present in 0.7.5. */
export const STALE_SYNTAX = [
  "--status idle",
  "--status done",
  "--split right",
  "wait agent-status",
  "wait output",
  "layout export",
] as const;

export type HerdrTaskClass = "syntax-discoverable" | "response-shape" | "semantics" | "recovery";

export type HerdrSkillEvalCase = {
  id: string;
  name: string;
  /** Which capability the task isolates. Drives per-class reporting. */
  taskClass: HerdrTaskClass;
  task: string;
  expected: {
    /** Substrings that must appear in the plan (command forms). */
    requiredCommands: string[];
    /** At least one must appear: alternative correct approaches. */
    anyOfCommands?: string[];
    /** Substrings that must NOT appear, beyond the global hallucination set. */
    forbiddenCommands: string[];
    /** Concepts the explanation must demonstrate. Scored by the semantic rubric. */
    requiredUnderstanding: string[];
  };
};

export const HERDR_SKILL_EVAL_CASES: HerdrSkillEvalCase[] = [
  {
    id: "start-and-prompt",
    name: "starts an agent in a fresh pane and collects its reply",
    taskClass: "syntax-discoverable",
    task: `
You are in a live herdr session. Start a second omp agent named "helper" beside
the current pane, ask it to summarize the repository README, and capture its
answer. Give the exact command sequence.
`,
    expected: {
      requiredCommands: [
        "pane split",
        "agent start",
        "--kind",
        "--pane",
        "agent prompt",
        "agent read",
      ],
      forbiddenCommands: ["agent start --cwd", "pane send-keys helper enter"],
      requiredUnderstanding: [
        "agent start requires an existing pane already at an interactive shell prompt",
        "agent prompt submits the text and Enter together",
      ],
    },
  },
  {
    id: "workspace-root-pane-shape",
    name: "uses root_pane from workspace create, not pane",
    taskClass: "response-shape",
    task: `
You are in a live herdr session. Create a new workspace for /tmp/demo labelled
"demo" without stealing focus, then run "npm test" in that workspace's pane.
Give the exact command sequence including how you obtain the pane id.

In your explanation, state where the pane id appears in the JSON returned by
\`workspace create\`, and how that location differs from the JSON returned by
\`pane split\`.
`,
    expected: {
      requiredCommands: ["workspace create", "pane run"],
      // Two correct ways to get the pane id: the literal key path, or
      // extract_ids.py, which the skill recommends *because* it absorbs the
      // root_pane/pane shape difference. Demanding the literal string scored
      // the brittle answer above the robust one.
      anyOfCommands: ["root_pane", "extract_ids.py"],
      forbiddenCommands: [".result.pane.pane_id"],
      requiredUnderstanding: [
        "workspace create returns its first tab and root pane; the pane id is at result.root_pane.pane_id",
        "pane split returns result.pane.pane_id instead, so the two response shapes differ",
      ],
    },
  },
  {
    id: "background-completion-unfocused",
    name: "recognizes done vs idle when the tab never gains focus",
    taskClass: "semantics",
    task: `
You dispatched a long refactor to agent "worker" in a background tab you will
not switch to. You are polling from the CLI only. Explain which agent state
signals that it finished, why polling for that state can look wrong, and give
the wait command you would run.
`,
    expected: {
      requiredCommands: ["agent wait", "--until", "--timeout"],
      forbiddenCommands: ["--status"],
      requiredUnderstanding: [
        "done is the completion state for background work whose tab has not been focused",
        "idle additionally requires the tab to have been seen in the focused UI",
        "CLI reads do not mark a tab as seen, so a background agent stays done rather than becoming idle",
      ],
    },
  },
  {
    id: "wait-timeout-recovery",
    name: "diagnoses a wait timeout instead of retrying blind",
    taskClass: "recovery",
    task: `
"herdr agent wait reviewer --until done --timeout 60000" exited 1 with a JSON
timeout error on stderr. Describe exactly what you do next, and why.
`,
    expected: {
      requiredCommands: ["agent read", "agent explain"],
      forbiddenCommands: [],
      requiredUnderstanding: [
        "read the agent output and detection evidence before issuing any further wait",
        "the agent may be blocked on an approval or question prompt rather than still working",
        "re-issuing the identical wait without inspecting state is the failure mode to avoid",
      ],
    },
  },
  {
    id: "altscreen-read",
    name: "handles a full-screen agent whose output is not in scrollback",
    taskClass: "semantics",
    task: `
You ran "herdr agent read coder --source recent-unwrapped --lines 200" against a
full-screen TUI agent and got far less text than the agent visibly displayed.
Raising --lines changes nothing. Explain the cause and what you do instead.
`,
    expected: {
      requiredCommands: ["--source visible"],
      forbiddenCommands: [],
      requiredUnderstanding: [
        "full-screen agents render on the terminal alternate screen",
        "alternate-screen rows never enter scrollback, so a larger --lines cannot recover them",
      ],
    },
  },
  {
    id: "reuse-existing-agent",
    name: "reuses an auto-created agent rather than spawning a duplicate",
    taskClass: "recovery",
    task: `
You just opened a herdr worktree workspace for a task and want an omp agent
working in it. Describe how you proceed so the workspace does not end up with
two agents.
`,
    expected: {
      requiredCommands: ["agent list"],
      forbiddenCommands: [],
      requiredUnderstanding: [
        "opening a workspace or worktree already creates panes that may hold an agent",
        "inspect existing agents and reuse an idle one before calling agent start",
      ],
    },
  },
  {
    id: "service-output-wait",
    name: "waits on pane output for a server, not on agent state",
    taskClass: "syntax-discoverable",
    task: `
Start "npm run dev" in a new pane and block until it prints "ready", then show
the last 40 lines. Give the exact commands.
`,
    expected: {
      requiredCommands: ["pane split", "pane run", "pane wait-output", "--match", "pane read"],
      forbiddenCommands: ["agent wait", "herdr wait output"],
      requiredUnderstanding: [
        "a plain process is not an agent, so wait on pane output rather than agent state",
      ],
    },
  },
  {
    id: "rename-consistency",
    name: "keeps tab labels honest after renaming a pane",
    taskClass: "semantics",
    task: `
You renamed a pane to reflect its new job. A teammate later says the tab label
still shows the old task. Explain what went wrong and how you target panes
reliably in future.
`,
    expected: {
      requiredCommands: ["tab rename"],
      forbiddenCommands: [],
      requiredUnderstanding: [
        "renaming a pane does not update its tab label",
        "labels drift and lie, so target using agent list cwd and session fields",
      ],
    },
  },
];
