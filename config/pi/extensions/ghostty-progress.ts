/**
 * Ghostty Progress Bar Extension
 *
 * Shows a progress bar in Ghostty's title bar using the ConEmu OSC 9;4
 * protocol. Provides visual feedback for agent activity:
 *
 * - Indeterminate (bouncing) while agent is working
 * - Context usage % after each turn (warning when high)
 * - Error state on tool failures (recovers on next successful turn)
 * - Resets after compaction to reflect freed context
 * - Clears on agent completion
 *
 * Protocol: ESC ] 9 ; 4 ; <state> ; <progress> BEL
 *   state 0 = hidden, 1 = normal, 2 = error, 3 = indeterminate, 4 = warning
 *   progress = 0-100
 *
 * https://martinemde.com/blog/ghostty-progress-bars
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const enum State {
  Hidden = 0,
  Normal = 1,
  Error = 2,
  Indeterminate = 3,
  Warning = 4,
}

/** Context usage % above which bar turns warning (yellow). */
const WARNING_THRESHOLD = 80;

/** Only emit on Ghostty (or terminals that support ConEmu OSC 9;4). */
function isGhostty(): boolean {
  return process.env.TERM_PROGRAM === "ghostty" || process.env.GHOSTTY_RESOURCES_DIR != null;
}

function emit(state: State, progress?: number): void {
  let seq = progress !== undefined ? `\x1b]9;4;${state};${progress}\x07` : `\x1b]9;4;${state}\x07`;

  // tmux passthrough
  if (process.env.TMUX) {
    const escaped = seq.split("\x1b").join("\x1b\x1b");
    seq = `\x1bPtmux;${escaped}\x1b\\`;
  }

  process.stdout.write(seq);
}

export default function (pi: ExtensionAPI) {
  if (!isGhostty()) return; // no-op on other terminals

  let errorThisTurn = false;

  // Agent starts working → indeterminate bounce
  pi.on("agent_start", async () => {
    errorThisTurn = false;
    emit(State.Indeterminate);
  });

  // Tool error → flash error state (resets on next successful turn)
  pi.on("tool_execution_end", async (event) => {
    if (event.isError) {
      errorThisTurn = true;
      emit(State.Error);
    }
  });

  // After each turn, show context usage
  pi.on("turn_end", async (_event, ctx) => {
    const usage = ctx.getContextUsage();
    if (usage?.percent == null) return;

    const pct = Math.round(usage.percent);
    let state: State;

    if (errorThisTurn) {
      state = State.Error;
    } else if (pct >= WARNING_THRESHOLD) {
      state = State.Warning;
    } else {
      state = State.Normal;
    }

    emit(state, pct);
    errorThisTurn = false; // recover after reporting
  });

  // After compaction, context drops — update bar to reflect
  pi.on("session_compact", async (_event, ctx) => {
    const usage = ctx.getContextUsage();
    if (usage?.percent != null) {
      emit(State.Normal, Math.round(usage.percent));
    }
  });

  // Agent done → clear
  pi.on("agent_end", async () => {
    emit(State.Hidden);
  });

  // Clean up on exit
  pi.on("session_shutdown", async () => {
    emit(State.Hidden);
  });
}
