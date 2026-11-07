import { execFileSync } from "node:child_process";
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const metadataPath = join(here, "package-harness.json");
const metadata = JSON.parse(readFileSync(metadataPath, "utf8"));
const candidate =
  process.argv[2] ??
  execFileSync(
    "gh",
    ["api", "repos/cursor/plugins/commits?path=pstack&per_page=1", "--jq", ".[0].sha"],
    { encoding: "utf8" }
  ).trim();
if (!/^[a-f0-9]{40}$/.test(candidate)) {
  throw new Error("Expected a full Cursor plugins commit SHA");
}
if (candidate === metadata.ref) {
  console.log(`Pistack is current at ${candidate}`);
  process.exit(0);
}

const fetched = JSON.parse(
  execFileSync(
    "nix",
    [
      "store",
      "prefetch-file",
      "--unpack",
      "--json",
      `https://api.github.com/repos/cursor/plugins/tarball/${candidate}`,
    ],
    { encoding: "utf8" }
  )
);
const temporary = mkdtempSync(join(tmpdir(), "pistack-update-"));
try {
  const source = join(temporary, "source");
  cpSync(fetched.storePath, source, { recursive: true });
  execFileSync("chmod", ["-R", "u+w", source]);
  for (const patch of metadata.patches) {
    const path = join(here, patch);
    execFileSync("git", ["apply", "--check", path], { cwd: source, stdio: "inherit" });
    execFileSync("git", ["apply", path], { cwd: source, stdio: "inherit" });
  }
  execFileSync(process.execPath, ["--test", join(here, "build.test.mjs")], {
    env: { ...process.env, PSTACK_SOURCE: source },
    stdio: "inherit",
  });
  const nixPath = join(here, "default.nix");
  const nix = readFileSync(nixPath, "utf8");
  const hashes = [...nix.matchAll(/hash = "sha256-[^"]+";/g)];
  if (hashes.length !== 1) throw new Error("Expected exactly one source hash in default.nix");
  const updatedNix = nix.replace(hashes[0][0], `hash = "${fetched.hash}";`);
  writeFileSync(nixPath, updatedNix);
  writeFileSync(metadataPath, JSON.stringify({ ...metadata, ref: candidate }, null, 2) + "\n");
  console.log(`Updated pistack: ${metadata.ref} -> ${candidate}`);
  console.log(
    `Review upstream: https://github.com/cursor/plugins/compare/${metadata.ref}...${candidate}`
  );
  console.log(
    "Pin and hash changed only after the local patches and content tests passed. Host activation is separate."
  );
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
