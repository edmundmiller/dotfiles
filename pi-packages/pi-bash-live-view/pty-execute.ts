import { getShellConfig, type ExtensionContext } from "@mariozechner/pi-coding-agent";
import {
  buildAbortError,
  buildExitCodeError,
  buildSuccessfulBashResult,
  buildTimeoutError,
} from "./truncate.ts";
import { hideWidget, showWidget, type LiveSession } from "./widget.ts";
import { PtyTerminalSession } from "./pty-session.ts";

export const WIDGET_DELAY_MS = 100;
export const WIDGET_HEIGHT = 15;
export const DEFAULT_PTY_COLS = 100;
export const XTERM_SCROLLBACK_LINES = 100_000;

export async function executePtyCommand(
  toolCallId: string,
  params: { command: string; timeout?: number },
  signal: AbortSignal | undefined,
  ctx: ExtensionContext
) {
  const normalizedSignal = signal ?? new AbortController().signal;
  const shellConfig = getShellConfig();
  const cols = DEFAULT_PTY_COLS;
  const rows = WIDGET_HEIGHT;
  const ptySession = new PtyTerminalSession({
    command: params.command,
    cwd: ctx.cwd,
    cols,
    rows,
    scrollback: XTERM_SCROLLBACK_LINES,
    shell: shellConfig.shell,
    shellArgs: shellConfig.args,
  });

  const session: LiveSession = {
    id: toolCallId,
    startedAt: Date.now(),
    rows,
    visible: false,
    disposed: false,
    session: ptySession,
  };

  const unsubscribe = ptySession.subscribe(() => {
    session.requestRender?.();
  });

  if (ctx.hasUI) {
    session.timer = setTimeout(() => showWidget(ctx, session), WIDGET_DELAY_MS);
  }

  let timeoutHandle: NodeJS.Timeout | undefined;
  let timedOut = false;
  let aborted = false;

  const kill = () => {
    ptySession.kill();
  };
  const onAbort = () => {
    aborted = true;
    kill();
  };

  if (params.timeout && params.timeout > 0) {
    timeoutHandle = setTimeout(() => {
      timedOut = true;
      kill();
    }, params.timeout * 1000);
  }
  if (normalizedSignal.aborted) {
    onAbort();
  } else {
    normalizedSignal.addEventListener("abort", onAbort, { once: true });
  }

  const exit = await new Promise<{ exitCode: number | null }>((resolve) => {
    ptySession.addExitListener((exitCode) => resolve({ exitCode }));
  });

  await ptySession.whenIdle();
  if (timeoutHandle) clearTimeout(timeoutHandle);
  normalizedSignal.removeEventListener("abort", onAbort);
  if (session.timer) clearTimeout(session.timer);
  session.disposed = true;
  hideWidget(ctx, session);
  unsubscribe();

  const fullText = ptySession.getStrippedTextIncludingEntireScrollback();
  ptySession.dispose();

  if (aborted) {
    throw buildAbortError(fullText);
  }
  if (timedOut && params.timeout && params.timeout > 0) {
    throw buildTimeoutError(fullText, params.timeout);
  }
  if (exit.exitCode !== 0 && exit.exitCode !== null) {
    throw buildExitCodeError(fullText, exit.exitCode);
  }

  return buildSuccessfulBashResult(fullText);
}
