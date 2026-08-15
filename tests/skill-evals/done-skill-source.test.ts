import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const root = fileURLToPath(new URL("../..", import.meta.url));
const skill = readFileSync(`${root}/skills/catalog/done/SKILL.md`, "utf8");
const referencesRoot = `${root}/skills/catalog/done/references`;
const contract =
  skill +
  readdirSync(referencesRoot)
    .filter((name) => name.endsWith(".md"))
    .sort()
    .map((name) => readFileSync(`${referencesRoot}/${name}`, "utf8"))
    .join("\n");

describe("done skill dirty default checkout contract", () => {
  it("tries a safe fast-forward before blocking on dirty canonical main", () => {
    expect(contract).toContain("temporary integration worktree");
    expect(contract).toContain("merge --ff-only");
    expect(contract).toContain("only when Git refuses");
    expect(contract).toMatch(/Never move\s+that checkout to a preservation branch/);
  });

  it("reconciles concurrent remote advancement without duplicating landed task work", () => {
    expect(contract).toContain("expected reconciliation event");
    expect(contract).toContain("patch-equivalent");
    expect(contract).toContain("later local-only commits");
    expect(contract).toContain("without publication authority");
    expect(contract).toContain("verify that unrelated dirt is byte-for-byte unchanged");
    expect(contract).toContain("Do not use `--force` or `--no-verify`");
    expect(contract).toContain("identity hook");
  });
});
