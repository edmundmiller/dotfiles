import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../..", import.meta.url));
const skillDir = `${root}/skills/conditional/herdr/herdr`;

/**
 * Exactly which files each arm injects. Pinned on purpose: "the skill, loaded
 * progressively" is not reproducible, so every arm names its inputs.
 */
export const ARM_SOURCES = {
  full: [
    `${skillDir}/SKILL.md`,
    `${skillDir}/references/cli-map.md`,
    `${skillDir}/references/recipes.md`,
  ],
  minimal: [],
  helpOnly: [],
} as const;

export type ArmId = keyof typeof ARM_SOURCES;

/**
 * Semantics that no amount of `--help` reading can supply: they describe UI
 * coupling, terminal behavior, and response shapes rather than flags. Arm
 * `minimal` is the hypothesis that this is the skill's entire irreducible core.
 */
const MINIMAL_SEMANTICS = `# Herdr: non-obvious behavior

Discover all syntax with \`herdr <group> --help\` and \`herdr <group> <subcommand> --help\`.
The installed CLI is the source of truth for commands, flags, and defaults.

The following cannot be discovered from help output:

- \`idle\` means ready AND the agent's tab has been seen in the focused UI.
  \`done\` is that same ready state after background work, held until the tab
  gains focus. CLI reads do NOT mark a tab as seen, so an agent working in a
  background tab settles on \`done\` and never reaches \`idle\`. \`unknown\` is
  not a successful completion.
- Response shapes differ: \`workspace create\` and \`tab create\` return the new
  pane at \`.result.root_pane.pane_id\`, while \`pane split\` returns
  \`.result.pane.pane_id\` and \`pane move\` returns
  \`.result.move_result.pane.pane_id\`.
- Full-screen agents render on the terminal alternate screen. Those rows never
  enter scrollback, so raising \`--lines\` cannot recover them; read
  \`--source visible\` instead.
- Opening a workspace or worktree already creates panes that may hold an agent.
  Check for an existing agent before starting another one.
- Renaming a pane does not rename its tab, so tab labels drift and lie. Target
  panes by their reported cwd and session identity rather than by label.
- On a wait timeout, read the agent's recent output and its detection evidence
  before issuing any further wait. Re-issuing an identical wait blind is the
  dominant observed failure.`;

const HELP_ONLY_PREAMBLE = `You have a live herdr session and full shell access.
No skill documentation is provided. The installed \`herdr\` CLI is the source of
truth: use \`herdr --help\`, \`herdr <group> --help\`, and
\`herdr <group> <subcommand> --help\` to discover whatever you need.`;

export function renderArmContext(arm: ArmId): string {
  if (arm === "helpOnly") return HELP_ONLY_PREAMBLE;
  if (arm === "minimal") {
    return `${HELP_ONLY_PREAMBLE}\n\nYou also have these notes:\n\n<herdr-notes>\n${MINIMAL_SEMANTICS}\n</herdr-notes>`;
  }

  const docs = ARM_SOURCES.full
    .map(
      (path) => `<file path="${path.replace(root, "")}">\n${readFileSync(path, "utf8")}\n</file>`
    )
    .join("\n\n");
  return `You have a live herdr session and full shell access. You may also run
\`herdr --help\` at any time. The following skill documentation is available:\n\n${docs}`;
}

export const MINIMAL_SKILL_TEXT = MINIMAL_SEMANTICS;
