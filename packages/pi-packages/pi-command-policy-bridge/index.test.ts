import { describe, expect, it } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import commandPolicyBridge, { evaluateToolGuard } from "./index";

const repoPolicyPath = join(import.meta.dir, "../../../config/pi/pi-permission-system.jsonc");

describe("pi-command-policy-bridge", () => {
  it("guards Codex and current Herdr commands with the repository policy", () => {
    const previous = process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
    process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = repoPolicyPath;
    try {
      for (const command of ["brew install foo", "echo safe"]) {
        const expected = command.startsWith("brew") ? "deny" : "allow";
        expect(evaluateToolGuard({ toolName: "exec_command", input: { cmd: command } }).kind).toBe(
          expected
        );
        expect(
          evaluateToolGuard({ toolName: "herdr_pane", input: { action: "run", command } }).kind
        ).toBe(expected);
      }
      expect(evaluateToolGuard({ toolName: "herdr_pane", input: { action: "list" } }).kind).toBe(
        "allow"
      );
    } finally {
      if (previous === undefined) delete process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
      else process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = previous;
    }
  });

  it("uses exec_command workdir to detect jj repositories", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-exec-policy-test-"));
    mkdirSync(join(dir, ".jj"));
    try {
      expect(
        evaluateToolGuard({ toolName: "exec_command", input: { cmd: "git add .", workdir: dir } })
          .kind
      ).toBe("deny");
      expect(
        evaluateToolGuard({ toolName: "exec_command", input: { cmd: "git status", workdir: dir } })
          .kind
      ).toBe("allow");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("blocks unchecked patches and stdin writes but allows polling", () => {
    expect(
      evaluateToolGuard({ toolName: "apply_patch", input: { patch: "*** Delete File: .env" } }).kind
    ).toBe("deny");
    for (const chars of ["brew install foo\n", "\n", " "]) {
      expect(evaluateToolGuard({ toolName: "write_stdin", input: { chars } }).kind).toBe("deny");
    }
    expect(evaluateToolGuard({ toolName: "write_stdin", input: { chars: "" } }).kind).toBe("allow");
    expect(evaluateToolGuard({ toolName: "write_stdin", input: {} }).kind).toBe("allow");
  });

  it("allows git mutations outside jj repositories", () => {
    const decision = evaluateToolGuard({
      toolName: "bash",
      input: { command: "git add ." },
    });
    expect(decision.kind).toBe("allow");
  });

  it("blocks git mutations inside jj repositories with a jj replacement", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-jj-policy-test-"));
    mkdirSync(join(dir, ".jj"));
    try {
      for (const command of [
        "git add .",
        "git commit -m feature",
        "git reset --hard HEAD~1",
        "git checkout main",
        "git rebase main",
        "git merge feature",
        "git push origin main",
        "git pull --rebase",
        "git restore state.txt",
        "git clean -fd",
        "git cherry-pick deadbeef",
      ]) {
        const decision = evaluateToolGuard({
          toolName: "bash",
          input: { command },
          workingDirectory: dir,
        });
        expect(decision.kind).toBe("deny");
        if (decision.kind === "deny") expect(decision.reason).toContain("jj");
      }
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("allows read-only git inspection inside jj repositories", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-jj-policy-test-"));
    mkdirSync(join(dir, ".jj"));
    try {
      for (const command of ["git status", "git diff", "git log -1", "git show HEAD"]) {
        const decision = evaluateToolGuard({
          toolName: "bash",
          input: { command },
          workingDirectory: dir,
        });
        expect(decision.kind).toBe("allow");
      }
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("guards jj_vcs align_push but allows status", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-jj-policy-test-"));
    mkdirSync(join(dir, ".jj"));
    try {
      const guarded = evaluateToolGuard({
        toolName: "jj_vcs",
        input: { action: "align_push" },
        workingDirectory: dir,
      });
      expect(guarded.kind).toBe("deny");
      const status = evaluateToolGuard({
        toolName: "jj_vcs",
        input: { action: "status" },
        workingDirectory: dir,
      });
      expect(status.kind).toBe("allow");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("allows commands with no readable bash policy", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-missing-policy-test-"));
    const previous = process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
    process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = join(dir, "missing.jsonc");

    try {
      const decision = evaluateToolGuard({
        toolName: "bash",
        input: { command: "echo safe" },
      });
      expect(decision.kind).toBe("allow");
    } finally {
      if (previous === undefined) {
        delete process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
      } else {
        process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = previous;
      }
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("requires approval for bash policy ask rules", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-policy-test-"));
    const previous = process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
    const configPath = join(dir, "config.jsonc");
    process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = configPath;
    writeFileSync(configPath, '{ "permission": { "bash": { "*": "ask" } } }');

    try {
      const decision = evaluateToolGuard({
        toolName: "bash",
        input: { command: "echo safe" },
      });
      expect(decision.kind).toBe("ask");
    } finally {
      if (previous === undefined) {
        delete process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
      } else {
        process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = previous;
      }
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("denies explicit bash policy deny rules", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-deny-policy-test-"));
    const previous = process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
    const configPath = join(dir, "config.jsonc");
    process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = configPath;
    writeFileSync(
      configPath,
      '{ "permission": { "bash": { "*": "allow", "*brew install*": "deny" } } }'
    );

    try {
      const decision = evaluateToolGuard({
        toolName: "bash",
        input: { command: "brew install foo" },
      });
      expect(decision.kind).toBe("deny");
    } finally {
      if (previous === undefined) {
        delete process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
      } else {
        process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = previous;
      }
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("treats foot-gun rules as explicit denies, not prompts", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-footgun-policy-test-"));
    const previous = process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
    const configPath = join(dir, "config.jsonc");
    process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = configPath;
    writeFileSync(
      configPath,
      '{ "permission": { "bash": { "*": "allow", "*git rebase -i*": "deny" } } }'
    );

    try {
      const decision = evaluateToolGuard({
        toolName: "bash",
        input: { command: "git rebase -i HEAD~3" },
      });
      expect(decision.kind).toBe("deny");
    } finally {
      if (previous === undefined) {
        delete process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
      } else {
        process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = previous;
      }
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("repo policy denies explicit local NUC eval commands", () => {
    const previous = process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
    process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = repoPolicyPath;

    try {
      const blocked = [
        "nix eval .#nixosConfigurations.nuc.config.system.build.toplevel",
        "nix build .#nixosConfigurations.nuc.config.system.build.toplevel",
        "nixos-rebuild build --flake .#nuc",
      ];

      for (const command of blocked) {
        const decision = evaluateToolGuard({
          toolName: "bash",
          input: { command },
        });
        expect(decision.kind).toBe("deny");
      }

      const processDecision = evaluateToolGuard({
        toolName: "process",
        input: {
          action: "start",
          command: "nix build .#nixosConfigurations.nuc.config.system.build.toplevel",
        },
      });
      expect(processDecision.kind).toBe("deny");
    } finally {
      if (previous === undefined) {
        delete process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
      } else {
        process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = previous;
      }
    }
  });

  it("repo policy requires approval for project task runners through every shell tool", () => {
    const previous = process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
    process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = repoPolicyPath;

    try {
      const commands = [
        "hey re",
        "hey gc",
        "hey nuc-wt build",
        "hey nuc dry-activate",
        "hey deploy-check",
        "mise run re",
        "mise re",
        "mise --cd /tmp/other run deploy nuc",
        "env TEST=1 /usr/local/bin/mise run gc",
        '"/usr/local/bin/mise" run re',
        "echo first;hey re",
        "echo first\nmise run re",
        "br list && hey re",
        "hey re && br list",
        "hey",
        "mise",
      ];

      for (const command of commands) {
        for (const toolName of [
          "bash",
          "exec_command",
          "process",
          "interactive_shell",
          "herdr_run_in_pane",
          "herdr_pane",
        ]) {
          const input = { command, cmd: command, action: toolName === "process" ? "start" : "run" };
          expect(evaluateToolGuard({ toolName, input }).kind).toBe("ask");
        }
      }
      expect(
        evaluateToolGuard({ toolName: "bash", input: { command: "nix flake check" } }).kind
      ).toBe("allow");
      expect(
        evaluateToolGuard({ toolName: "bash", input: { command: "hey re && brew install foo" } })
          .kind
      ).toBe("deny");
    } finally {
      if (previous === undefined) {
        delete process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
      } else {
        process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = previous;
      }
    }
  });

  it("executes ask commands only after explicit UI approval, including with yolo enabled", async () => {
    const previous = process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
    process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = repoPolicyPath;
    type Handler = (
      event: { toolName: string; input: { command: string } },
      ctx: {
        hasUI: boolean;
        ui: { confirm(): Promise<boolean> };
      }
    ) => Promise<{ block: boolean; reason: string } | undefined>;
    let handler: Handler | undefined;
    const api: Partial<ExtensionAPI> = {
      on(_name, callback) {
        // SAFETY: The bridge registers only tool_call; the fixture supplies its consumed fields.
        handler = callback as Handler;
      },
    };
    // SAFETY: Registration is the only ExtensionAPI member the bridge uses.
    commandPolicyBridge(api as ExtensionAPI);
    if (!handler) throw new Error("tool_call was not registered");
    try {
      for (const [hasUI, approves, blocked] of [
        [true, true, false],
        [true, false, true],
        [false, true, true],
      ]) {
        const result = await handler(
          { toolName: "bash", input: { command: "mise run re" } },
          {
            hasUI,
            ui: { confirm: async () => approves },
          }
        );
        expect(result?.block ?? false).toBe(blocked);
      }
      const failedDialog = await handler(
        { toolName: "bash", input: { command: "mise run re" } },
        {
          hasUI: true,
          ui: {
            confirm: async () => {
              throw new Error("UI disconnected");
            },
          },
        }
      );
      expect(failedDialog?.block).toBe(true);
    } finally {
      if (previous === undefined) delete process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
      else process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = previous;
    }
  });
});
