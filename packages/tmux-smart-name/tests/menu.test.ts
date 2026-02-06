import { describe, expect, test } from "bun:test";
import { generateMenuCommand, type AgentInfo } from "../src/menu";
import { ICON_IDLE, ICON_BUSY, ICON_ERROR, ICON_WAITING } from "../src/status";

describe("generateMenuCommand", () => {
  test("returns null for empty agents", () => {
    expect(generateMenuCommand([])).toBeNull();
  });

  test("single agent", () => {
    const agents: AgentInfo[] = [
      {
        session: "main",
        windowIndex: "0",
        windowName: "dev",
        paneId: "%1",
        program: "opencode",
        status: ICON_BUSY,
        path: "~/project",
      },
    ];
    const cmd = generateMenuCommand(agents)!;
    expect(cmd).toContain("display-menu");
    expect(cmd).toContain("Agent Management");
    expect(cmd).toContain("opencode");
    expect(cmd).toContain("main:0");
  });

  test("sorts error before idle", () => {
    const agents: AgentInfo[] = [
      {
        session: "a",
        windowIndex: "0",
        windowName: "dev",
        paneId: "%1",
        program: "opencode",
        status: ICON_IDLE,
        path: "",
      },
      {
        session: "b",
        windowIndex: "0",
        windowName: "dev",
        paneId: "%2",
        program: "claude",
        status: ICON_ERROR,
        path: "",
      },
    ];
    const cmd = generateMenuCommand(agents)!;
    expect(cmd.indexOf("claude")).toBeLessThan(cmd.indexOf("opencode"));
  });

  test("shows attention count", () => {
    const agents: AgentInfo[] = [
      {
        session: "a",
        windowIndex: "0",
        windowName: "dev",
        paneId: "%1",
        program: "opencode",
        status: ICON_ERROR,
        path: "",
      },
      {
        session: "b",
        windowIndex: "0",
        windowName: "dev",
        paneId: "%2",
        program: "claude",
        status: ICON_WAITING,
        path: "",
      },
      {
        session: "c",
        windowIndex: "0",
        windowName: "dev",
        paneId: "%3",
        program: "opencode",
        status: ICON_IDLE,
        path: "",
      },
    ];
    const cmd = generateMenuCommand(agents)!;
    expect(cmd).toContain("3 agents");
    expect(cmd).toContain("2 need attention");
  });
});
