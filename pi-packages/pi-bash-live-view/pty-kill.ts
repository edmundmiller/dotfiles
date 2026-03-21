import type pty from "node-pty";

export type PtyLikeProcess = {
  pid: number;
  kill: (signal?: string) => void;
};

export function killPtyProcess(ptyProcess: PtyLikeProcess, signal: string = "SIGTERM"): void {
  const pid = ptyProcess.pid;

  if (process.platform !== "win32" && pid) {
    try {
      process.kill(-pid, signal as NodeJS.Signals);
      return;
    } catch {
      // Fall through to direct PTY kill.
    }
  }

  try {
    ptyProcess.kill(signal);
  } catch {
    // Process may already be dead.
  }
}
