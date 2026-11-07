import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const source = process.env.PSTACK_SOURCE;
assert.ok(source, "Set PSTACK_SOURCE to the patched Cursor checkout");
const temporary = mkdtempSync(join(tmpdir(), "pistack-build-test-"));
after(() => rmSync(temporary, { recursive: true, force: true }));
const output = join(temporary, "package");
execFileSync(process.execPath, [join(here, "build.mjs"), source, output, join(here, "PI.md")]);
const manifest = JSON.parse(readFileSync(join(output, "package.json"), "utf8"));
const upstream = join(source, "pstack");

test("registers all upstream skills except canonical shared copies", () => {
  assert.equal(manifest.name, "pistack");
  const expected = readdirSync(join(upstream, "skills"))
    .filter((name) => !["tdd", "teach", "unslop"].includes(name))
    .sort()
    .map((name) => `./skills/${name}`);
  assert.deepEqual(manifest.pi.skills, expected);
  assert.ok(manifest.pi.skills.includes("./skills/sharpen"));
  assert.ok(manifest.pi.skills.includes("./skills/statechart"));
  assert.ok(manifest.pi.skills.includes("./skills/how"));
  assert.deepEqual(manifest.pi.extensions, []);
  assert.deepEqual(manifest.pi.subagents.agents, ["./agents"]);
});

test("maps Cursor skill storage to Pi discovery and preserves shared catalog ownership", () => {
  const contract = readFileSync(join(output, "PI.md"), "utf8");
  assert.match(contract, /\|\s*`\.cursor\/skills\/`\s*\|\s*`\.pi\/skills\/`\s*\|/);
  assert.match(contract, /\|\s*`~\/\.cursor\/skills\/`\s*\|\s*`~\/\.pi\/agent\/skills\/`\s*\|/);
  assert.ok(contract.includes("`.agents/skills/`"));
  assert.ok(contract.includes("`~/.agents/skills/`"));
  assert.ok(contract.includes("`skills/catalog/`"));
});

test("preserves upstream content and routes every skill and agent through the Pi contract", () => {
  const files = readdirSync(upstream, { recursive: true, withFileTypes: true }).filter((entry) =>
    entry.isFile()
  );
  for (const entry of files) {
    const relative = join(entry.parentPath, entry.name).slice(upstream.length + 1);
    const original = readFileSync(join(upstream, relative));
    const built = readFileSync(join(output, relative));
    if (/^skills\/[^/]+\/SKILL\.md$|^agents\/[^/]+\.md$/.test(relative)) {
      const text = built.toString();
      const header = text.match(
        /\n## Pi compatibility\n\nRead \[the Pi runtime contract\]\(([^)]+)\)[^\n]*\n/
      );
      assert.ok(header, relative);
      assert.equal(resolve(dirname(join(output, relative)), header[1]), join(output, "PI.md"));
      assert.equal(text.replace(header[0], ""), original.toString(), relative);
    } else {
      assert.deepEqual(built, original, relative);
    }
  }
  assert.match(
    readFileSync(join(output, "skills/sharpen/SKILL.md"), "utf8"),
    /Then rewrite my prompt/
  );
  assert.match(
    readFileSync(join(output, "skills/poteto-mode/SKILL.md"), "utf8"),
    /Pi execution override/
  );
  assert.match(
    readFileSync(join(output, "agents/poteto-agent.md"), "utf8"),
    /inheritProjectContext: true/
  );
});
