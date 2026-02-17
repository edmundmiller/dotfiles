/**
 * Ghostty Progress Bar Extension
 *
 * Shows a progress bar in Ghostty's title bar using the ConEmu OSC 9;4
 * protocol. Provides visual feedback for agent activity:
 *
 * - Indeterminate (bouncing) while agent is working
 * - Context usage % after each turn
 * - Error state on tool failures
 * - Clears on agent completion
 *
 * Protocol: ESC ] 9 ; 4 ; <state> ; <progress> BEL
 *   state 0 = hidden, 1 = normal, 2 = error, 3 = indeterminate
 *   progress = 0-100
 *
 * https://martinemde.com/blog/ghostty-progress-bars
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const enum ProgressState {
  Hidden = 0,
  Normal = 1,
  Error = 2,
  Indeterminate = 3,
}

function setProgress(state: ProgressState, progress?: number): void {
  let seq = progress !== undefined ? `\x1b]9;4;${state};${progress}\x07` : `\x1b]9;4;${state}\x07`;

  // tmux passthrough
  if (process.env.TMUX) {
    const escaped = seq.split("\x1b").join("\x1b\x1b");
    seq = `\x1bPtmux;${escaped}\x1b\\`;
  }

  process.stdout.write(seq);
}

export default function (pi: ExtensionAPI) {
  let hasError = false;

  // Agent starts working → indeterminate bounce
  pi.on("agent_start", async () => {
    hasError = false;
    setProgress(ProgressState.Indeterminate);
  });

  // After each turn, show context usage as progress
  pi.on("turn_end", async (_event, ctx) => {
    const usage = ctx.getContextUsage();
    if (usage?.percent != null) {
      setProgress(hasError ? ProgressState.Error : ProgressState.Normal, Math.round(usage.percent));
    }
  });

  // Tool error → switch to error state
  pi.on("tool_execution_end", async (event) => {
    if (event.isError) {
      hasError = true;
      setProgress(ProgressState.Error);
    }
  });

  // Agent done → clear
  pi.on("agent_end", async () => {
    setProgress(ProgressState.Hidden);
  });

  // Clean up on exit
  pi.on("session_shutdown", async () => {
    setProgress(ProgressState.Hidden);
  });
}
