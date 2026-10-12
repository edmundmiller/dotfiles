import { expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

// https://github.com/edmundmiller/dotfiles/issues/15
// Bun's blocked lifecycle scripts can hide failures that npm consumers encounter.
test("locked and packed npm installs run normal lifecycle scripts", () => {
  const root = mkdtempSync(join(tmpdir(), "pi-dcp-install-"));
  const source = resolve(import.meta.dir, "..");
  const env = {
    PATH: process.env.PATH,
    HOME: join(root, "home"),
    TMPDIR: root,
    npm_config_cache: join(root, "cache"),
    npm_config_userconfig: join(root, "npmrc"),
    npm_config_globalconfig: join(root, "global-npmrc"),
    npm_config_registry: "https://registry.npmjs.org",
    npm_config_ignore_scripts: "false",
    npm_config_audit: "false",
    npm_config_fund: "false",
  };
  const run = (command: string, args: string[], cwd = root) => {
    const result = spawnSync(command, args, {
      cwd,
      env,
      encoding: "utf8",
      timeout: 120_000,
    });
    if (result.error || result.status !== 0) {
      throw new Error(
        `${command} ${args.join(" ")}\n${result.error ?? ""}\n${result.stdout}\n${result.stderr}`
      );
    }
    return result.stdout.trim();
  };

  try {
    mkdirSync(env.HOME);
    const locked = join(root, "locked");
    mkdirSync(locked);
    for (const file of ["package.json", "package-lock.json"]) {
      copyFileSync(join(source, file), join(locked, file));
    }
    run("npm", ["ci", "--foreground-scripts"], locked);

    const tarball = run("npm", ["pack", source, "--silent", "--pack-destination", root]);
    for (const global of [false, true]) {
      const prefix = join(root, global ? "global" : "local");
      run("npm", [
        "install",
        "--foreground-scripts",
        "--prefix",
        prefix,
        ...(global ? ["--global"] : []),
        join(root, tarball),
      ]);
      const installed = join(prefix, global ? "lib/node_modules/pi-dcp" : "node_modules/pi-dcp");
      // Exercise the shipped entry point and loader, not the workspace's dependencies.
      const output = run(process.execPath, [
        "--eval",
        `
        import extension from ${JSON.stringify(join(installed, "index.ts"))};
        import { loadConfig } from ${JSON.stringify(join(installed, "src/config.ts"))};
        const config = await loadConfig({ getFlag: () => undefined });
        if (typeof extension !== "function" || !config.enabled || config.keepRecentCount !== 10) {
          throw new Error("Installed extension or default config is invalid");
        }
        console.log("installed extension loads");
      `,
      ]);
      expect(output).toContain("installed extension loads");
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}, 300_000);
