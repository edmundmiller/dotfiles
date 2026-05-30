import { describe, expect, it } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { evaluateToolGuard } from "./index";

describe("pi-command-policy-bridge", () => {
  it("does not block git commands", () => {
    const decision = evaluateToolGuard({
      toolName: "bash",
      input: { command: "git add ." },
    });
    expect(decision.kind).toBe("allow");
  });

  it("allows jj_vcs align_push without prompting", () => {
    const decision = evaluateToolGuard({
      toolName: "jj_vcs",
      input: { action: "align_push" },
      workingDirectory: process.cwd(),
    });
    expect(decision.kind).toBe("allow");
  });

  it("allows commands with no readable bash policy", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-missing-policy-test-"));
    const previous = process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR;
    process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR = dir;

    try {
      const decision = evaluateToolGuard({
        toolName: "bash",
        input: { command: "echo safe" },
      });
      expect(decision.kind).toBe("allow");
    } finally {
      if (previous === undefined) {
        delete process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR;
      } else {
        process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR = previous;
      }
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("allows bash policy ask rules without prompting", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-policy-test-"));
    const previous = process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR;
    process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR = dir;
    writeFileSync(join(dir, "pi-permissions.jsonc"), '{ "bash": { "*": "ask" } }');

    try {
      const decision = evaluateToolGuard({
        toolName: "bash",
        input: { command: "echo safe" },
      });
      expect(decision.kind).toBe("allow");
    } finally {
      if (previous === undefined) {
        delete process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR;
      } else {
        process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR = previous;
      }
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("denies explicit bash policy deny rules", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-deny-policy-test-"));
    const previous = process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR;
    process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR = dir;
    writeFileSync(
      join(dir, "pi-permissions.jsonc"),
      '{ "bash": { "*": "allow", "*brew install*": "deny" } }'
    );

    try {
      const decision = evaluateToolGuard({
        toolName: "bash",
        input: { command: "brew install foo" },
      });
      expect(decision.kind).toBe("deny");
    } finally {
      if (previous === undefined) {
        delete process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR;
      } else {
        process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR = previous;
      }
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("treats foot-gun rules as explicit denies, not prompts", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-footgun-policy-test-"));
    const previous = process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR;
    process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR = dir;
    writeFileSync(
      join(dir, "pi-permissions.jsonc"),
      '{ "bash": { "*": "allow", "*git rebase -i*": "deny" } }'
    );

    try {
      const decision = evaluateToolGuard({
        toolName: "bash",
        input: { command: "git rebase -i HEAD~3" },
      });
      expect(decision.kind).toBe("deny");
    } finally {
      if (previous === undefined) {
        delete process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR;
      } else {
        process.env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR = previous;
      }
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
