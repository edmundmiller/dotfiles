type MockExtensionAPI = {
  events: {
    on: (event: string, handler: (payload: any) => void) => void;
    emit: (event: string, payload?: any) => void;
  };
  on: (event: string, handler: (...args: any[]) => void) => void;
};

const sampleUsage = {
  provider: "codex",
  displayName: "OpenAI Codex",
  windows: [
    {
      label: "Week",
      usedPercent: 42,
      resetDescription: "in 6d",
      resetAt: new Date(Date.now() + 6 * 24 * 60 * 60 * 1000).toISOString(),
    },
    {
      label: "Primary",
      usedPercent: 15,
      resetDescription: "in 2h",
      resetAt: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(),
    },
  ],
};

export default function mockSubCore(pi: MockExtensionAPI): void {
  pi.events.on("sub-core:request", (request: any) => {
    if (request?.type === "entries") {
      request.reply?.({ entries: [{ provider: "codex", usage: sampleUsage }] });
      return;
    }
    request.reply?.({ state: { usage: sampleUsage } });
  });

  pi.on("session_start", () => {
    pi.events.emit("sub-core:ready", { state: { usage: sampleUsage } });
  });
}
