import { describe, expect, it } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { evaluateToolGuard } from "./index";

const repoPolicyPath = join(import.meta.dir, "../../../config/pi/pi-permission-system.jsonc");

describe("pi-command-policy-bridge", () => {
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

  it("allows bash policy ask rules without prompting", () => {
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

  it("repo policy allows blessed NUC validation commands", () => {
    const previous = process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
    process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = repoPolicyPath;

    try {
      const allowed = [
        "nix flake check",
        "hey nuc-wt build",
        "hey nuc dry-activate",
        "hey deploy-check",
      ];

      for (const command of allowed) {
        const decision = evaluateToolGuard({
          toolName: "bash",
          input: { command },
        });
        expect(decision.kind).toBe("allow");
      }
    } finally {
      if (previous === undefined) {
        delete process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH;
      } else {
        process.env.PI_PERMISSION_SYSTEM_CONFIG_PATH = previous;
      }
    }
  });
});
