import { readFile } from "node:fs/promises";
import { createInterface } from "node:readline";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";
import { loadTinyfix } from "tinyfix";

// The upstream loader uses fetch. Only bundled files are readable here; there
// is no HTTP server, network fallback, or first-launch model download.
const modelDirectory = pathToFileURL(`${resolve(process.argv[2])}/`);
const files = new Set([
  "words.txt",
  "wrong-word.onnx",
  "wrong-word-vocab.txt",
  "wrong-word-confusions.txt",
]);
globalThis.fetch = async (input) => {
  const url = new URL(input);
  const name = url.href.slice(modelDirectory.href.length);
  if (!url.href.startsWith(modelDirectory.href) || !files.has(name)) {
    throw new Error("TinyType blocked a non-bundled model request");
  }
  return new Response(await readFile(url));
};

const checker = await loadTinyfix({ baseUrl: modelDirectory, mode: "careful" });
process.stdout.write(`${JSON.stringify({ ready: true })}\n`);
for await (const line of createInterface({ input: process.stdin, crlfDelay: Infinity })) {
  try {
    const request = JSON.parse(line);
    if (request.op === "ignore") {
      checker.ignore(request.word);
      process.stdout.write("{}\n");
      continue;
    }
    // eslint-disable-next-line anti-slop/no-runtime-typeof -- This JSONL input boundary requires a bounded primitive string before inference.
    if (request.op !== "check" || typeof request.text !== "string" || request.text.length > 16384) {
      throw new Error("TinyType invalid check request");
    }
    const options = request.range ? { range: request.range } : {};
    const fixes = await checker.check(request.text, options);
    process.stdout.write(
      `${JSON.stringify({ fixes, text: checker.apply(request.text, fixes) })}\n`
    );
  } catch {
    // Never echo the request, text, or exception from a model back into logs.
    process.stdout.write(`${JSON.stringify({ error: "TinyType could not check this text" })}\n`);
  }
}
await checker.dispose();
