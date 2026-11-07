import { chmodSync, cpSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [source, output, adapter] = process.argv.slice(2);
if (!source || !output || !adapter) {
  throw new Error("Usage: node build.mjs <patched-cursor-source> <output> <PI.md>");
}

cpSync(join(source, "pstack"), output, { recursive: true });
cpSync(adapter, join(output, "PI.md"));

const skills = readdirSync(join(output, "skills"), { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort();
const shared = new Set(["tdd", "teach", "unslop"]);

for (const path of skills.map((name) => `skills/${name}/SKILL.md`)) {
  const file = join(output, path);
  const text = readFileSync(file, "utf8");
  const frontmatter = text.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n/);
  if (!frontmatter) throw new Error(`Missing frontmatter: ${path}`);
  const header = `\n## Pi compatibility\n\nRead [the Pi runtime contract](../../PI.md) before following these instructions. It overrides Cursor-specific mechanics throughout this skill and its references.\n`;
  chmodSync(file, statSync(file).mode | 0o200);
  writeFileSync(
    file,
    text.slice(0, frontmatter[0].length) + header + text.slice(frontmatter[0].length)
  );
}

const exposed = skills.filter((name) => !shared.has(name)).map((name) => `./skills/${name}`);
const plugin = JSON.parse(readFileSync(join(output, "plugin.json"), "utf8"));
writeFileSync(
  join(output, "package.json"),
  JSON.stringify(
    {
      name: "pistack",
      version: plugin.version,
      private: true,
      license: "MIT",
      type: "module",
      pi: {
        extensions: [],
        skills: exposed,
      },
    },
    null,
    2
  ) + "\n"
);
console.log(`Built pistack ${plugin.version}: ${exposed.length} package skills`);
