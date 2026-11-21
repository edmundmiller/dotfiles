import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const manifest = JSON.parse(await readFile(new URL("./models.json", import.meta.url), "utf8"));
const directory = resolve(process.argv[2] ?? ".models");
await mkdir(directory, { recursive: true });
for (const [name, expected] of Object.entries(manifest.files)) {
  const target = resolve(directory, name);
  let bytes;
  try {
    bytes = await readFile(target);
  } catch {
    /* Download a missing file. */
  }
  if (!bytes || createHash("sha256").update(bytes).digest("hex") !== expected) {
    const response = await fetch(
      `https://huggingface.co/paperweight/tinyfix/resolve/${manifest.revision}/${name}`
    );
    if (!response.ok)
      throw new Error(`TinyType model download failed: ${name}, HTTP ${response.status}`);
    bytes = Buffer.from(await response.arrayBuffer());
  }
  if (createHash("sha256").update(bytes).digest("hex") !== expected) {
    throw new Error(`TinyType model checksum mismatch: ${name}`);
  }
  await writeFile(target, bytes);
  console.log(`Verified ${name}`);
}
