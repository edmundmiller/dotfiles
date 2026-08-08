// Pure file discovery: resolve entry paths/globs under a root into a concrete
// list of source files, skipping vendored and build output directories.
import { Glob } from "bun";
import { isAbsolute, join } from "node:path";

const DEFAULT_GLOB = "**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs}";
const IGNORE = ["**/node_modules/**", "**/dist/**", "**/.git/**", "**/build/**"];
const SOURCE_EXT = /\.(mts|cts|ts|tsx|mjs|cjs|js|jsx)$/;

export function discover(root: string, paths: readonly string[]): string[] {
  const patterns = paths.length ? paths : [DEFAULT_GLOB];
  const seen = new Set<string>();
  for (const pattern of patterns) {
    const isConcreteFile = !pattern.includes("*") && SOURCE_EXT.test(pattern);
    if (isConcreteFile) {
      seen.add(isAbsolute(pattern) ? pattern : join(root, pattern));
      continue;
    }
    const glob = new Glob(pattern);
    for (const rel of glob.scanSync({ cwd: root, onlyFiles: true, dot: false })) {
      if (IGNORE.some((ig) => new Glob(ig).match(rel))) continue;
      seen.add(join(root, rel));
    }
  }
  return [...seen];
}
