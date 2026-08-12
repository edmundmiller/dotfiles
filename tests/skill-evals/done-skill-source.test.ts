import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const root = fileURLToPath(new URL("../..", import.meta.url));
const skill = readFileSync(`${root}/skills/catalog/done/SKILL.md`, "utf8");

describe("done skill dirty default checkout contract", () => {
  it("tries a safe fast-forward before blocking on dirty canonical main", () => {
    expect(skill).toContain("temporary integration worktree");
    expect(skill).toContain("merge --ff-only");
    expect(skill).toContain("only when Git refuses");
    expect(skill).toMatch(/Never move\s+that checkout to a preservation branch/);
  });

  it("reconciles concurrent remote advancement without duplicating landed task work", () => {
    expect(skill).toContain("expected reconciliation event");
    expect(skill).toContain("patch-equivalent");
    expect(skill).toContain("later local-only commits");
    expect(skill).toContain("Replay only those remaining local-only commits");
    expect(skill).toContain("verify that unrelated dirt is byte-for-byte unchanged");
    expect(skill).toContain("Do not use `--force` or `--no-verify`");
    expect(skill).toContain("identity hook");
  });
});
