import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const packageManifest = (packageName: string) =>
  JSON.parse(readFileSync(join(import.meta.dir, "..", packageName, "package.json"), "utf8"));

describe("OMP plugin packaging", () => {
  test("declares only runtime extensions", () => {
    expect(packageManifest("pi-herdr").pi.extensions).toEqual(["./extensions/herdr.ts"]);
    expect(packageManifest("pi-hunk").pi.extensions).toEqual(["./extensions/hunk.ts"]);
  });
});
