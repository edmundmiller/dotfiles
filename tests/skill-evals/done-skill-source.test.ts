import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const root = fileURLToPath(new URL("../..", import.meta.url));
const skill = readFileSync(`${root}/skills/catalog/done/SKILL.md`, "utf8");

describe("done skill dirty default checkout contract", () => {
  it("blocks without changing the branch meaning of dirty canonical main", () => {
    expect(skill).toContain("If the default branch's existing checkout has unrelated dirt");
    expect(skill).toMatch(/Never move that checkout to a\s+preservation branch/);
  });
});
