import { describe, expect, it } from "bun:test";
import { mkdtempSync, mkdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { evaluateToolGuard } from "./index";

describe("pi-command-policy-bridge jj behavior", () => {
    it("blocks git add in jj repos with remediation", () => {
        const dir = mkdtempSync(join(tmpdir(), "pi-jj-test-"));
        mkdirSync(join(dir, ".jj"));
        const decision = evaluateToolGuard({
            toolName: "bash",
            input: { command: "git add ." },
            workingDirectory: dir,
        });
        rmSync(dir, { recursive: true, force: true });
        expect(decision.kind).toBe("deny");
        if (decision.kind !== "deny") return;
        expect(decision.reason).toContain("jj snapshots automatically");
    });

    it("does not block git add outside jj repos", () => {
        const decision = evaluateToolGuard({
            toolName: "bash",
            input: { command: "git add ." },
            workingDirectory: "/tmp",
        });
        expect(decision.kind).toBe("allow");
    });

    it("requires approval for jj_vcs align_push", () => {
        const decision = evaluateToolGuard({
            toolName: "jj_vcs",
            input: { action: "align_push" },
            workingDirectory: process.cwd(),
        });
        expect(decision.kind).toBe("ask");
    });

    it("allows jj_vcs status", () => {
        const decision = evaluateToolGuard({
            toolName: "jj_vcs",
            input: { action: "status" },
            workingDirectory: process.cwd(),
        });
        expect(decision.kind).toBe("allow");
    });
});
