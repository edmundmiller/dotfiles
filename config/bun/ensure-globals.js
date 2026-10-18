import {
  accessSync,
  constants,
  existsSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";

// Activation sets BUN_INSTALL explicitly so inspection and installation agree.
const root = process.env.BUN_INSTALL;
const globalDir = join(root, "install/global");
const marker = join(globalDir, ".activation-incomplete");

function installed(spec) {
  const match = spec.match(/^(@[^/]+\/[^@]+|[^@/]+)@(\d+\.\d+\.\d+(?:-[\w.-]+)?(?:\+[\w.-]+)?)$/);
  // Tags, ranges, URLs and local paths still need Bun to resolve them.
  if (!match) return false;
  const [, name, version] = match;
  const directory = join(root, "install/global/node_modules", name);
  try {
    const pkg = JSON.parse(readFileSync(join(directory, "package.json"), "utf8"));
    if (pkg.version !== version) return false;
    // oxlint-disable-next-line anti-slop/no-runtime-typeof -- npm's external bin field accepts a string or a command map.
    const bins = typeof pkg.bin === "string" ? { [name.split("/").pop()]: pkg.bin } : pkg.bin || {};
    return Object.entries(bins).every(([command, target]) => {
      const link = join(root, "bin", command);
      accessSync(link, constants.X_OK);
      return realpathSync(link) === realpathSync(join(directory, target));
    });
  } catch (error) {
    if (
      error instanceof SyntaxError ||
      ["ENOENT", "EACCES", "ENOTDIR", "ELOOP"].includes(error.code)
    ) {
      return false;
    }
    throw error;
  }
}

const incomplete = existsSync(marker);
const pending = process.argv.slice(2).filter((spec) => incomplete || !installed(spec));
if (pending.length) {
  // Bun links binaries before postinstall. Keep failed/interrupted attempts
  // dirty even when versions and executables look correct. The marker covers
  // the whole global directory because --force reinstalls all its dependencies.
  mkdirSync(globalDir, { recursive: true });
  writeFileSync(marker, "");
  console.error(`Installing bun global packages: ${pending.join(" ")}`);
  const install = (force) => {
    const result = Bun.spawnSync(
      [process.execPath, "install", "-g", ...(force ? ["--force"] : []), ...pending],
      { stdout: "pipe", stderr: "pipe" }
    );
    process.stdout.write(result.stdout);
    process.stderr.write(result.stderr);
    return result;
  };
  // A normal cached install may skip the failed lifecycle script.
  let result = install(incomplete);
  // Repair the historical existing-link failure, not network or script failures.
  if (!incomplete && result.exitCode !== 0 && /\bEEXIST\b/.test(result.stderr.toString())) {
    result = install(true);
  }
  if (result.exitCode !== 0) process.exit(result.exitCode);
  unlinkSync(marker);
}
