import { afterAll, beforeAll, expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createPtyHarness } from "./test/pty/harness";

const executable = process.env.HUNK_TEST_EXECUTABLE!;
const repo = mkdtempSync(join(tmpdir(), "hunk-package-"));
const configHome = join(repo, "config");
const env = {
  ...process.env,
  HOME: repo,
  XDG_CONFIG_HOME: configHome,
  XDG_STATE_HOME: join(repo, "state"),
  GIT_CONFIG_GLOBAL: "/dev/null",
  GIT_CONFIG_NOSYSTEM: "1",
  HUNK_DISABLE_UPDATE_NOTICE: "1",
  HUNK_MCP_DISABLE: "1",
  HUNK_JEV_PRIORITY: "1",
  TYPESAFE_API_KEY: "",
};
const harness = createPtyHarness();

function run(args: string[]) {
  return Bun.spawnSync([executable, ...args], { cwd: repo, env, stdout: "pipe", stderr: "pipe" });
}

beforeAll(() => {
  const git = (...args: string[]) => {
    const result = Bun.spawnSync(["git", ...args], { cwd: repo, env });
    expect(result.exitCode).toBe(0);
  };
  git("init", "-q");
  git("config", "user.name", "Package test");
  git("config", "user.email", "test@example.com");
  git("config", "commit.gpgsign", "false");
  git("config", "core.hooksPath", "/dev/null");
  writeFileSync(join(repo, "README.md"), "# Authentication\n");
  writeFileSync(join(repo, "auth.ts"), "export const authenticated = false;\n");
  git("add", ".");
  git("commit", "-qm", "Initial example");
  writeFileSync(join(repo, "README.md"), "# Authentication\nRequire authentication.\n");
  writeFileSync(join(repo, "auth.ts"), "export const authenticated = true;\n");
  git("add", ".");
  git("commit", "-qm", "Require authentication");
  mkdirSync(join(configHome, "hunk"), { recursive: true });
  writeFileSync(
    join(configHome, "hunk/config.toml"),
    '[keybindings]\n"hunk-commit-log.next" = "ctrl+n"\n'
  );
  // A built-in's name used as an option value must not be mistaken for the command.
  mkdirSync(join(repo, "session"));
  writeFileSync(
    join(repo, "session/index.ts"),
    `export default function(hunk) {
    hunk.registerCliCommand({ name: "probe", summary: "Echo arguments" }, async (args, ctx) => {
      await ctx.stdout.write(JSON.stringify(args));
      return { kind: "exit", code: 0 };
    });
  }`
  );
});

afterAll(() => {
  harness.cleanup();
  rmSync(repo, { recursive: true, force: true });
});

test.each([
  [["skill", "path"]],
  [["completion", "--help"]],
  [["extension", "list", "--help"]],
  [["session", "--help"]],
  [["open", "--help"]],
])("installed wrapper preserves non-review built-in: %j", (args) => {
  const result = run(args);
  expect(result.stderr.toString()).toBe("");
  expect(result.exitCode).toBe(0);
  if (args[0] === "skill") expect(existsSync(result.stdout.toString().trim())).toBe(true);
  else expect(result.stdout.toString()).toContain("Usage:");
});

test.each([[["--extension", "session"]], [["--extension=session"]]])(
  "installed wrapper preserves custom commands and arguments: %j",
  (flags) => {
    const args = ["two words", "--", "session", "semi;literal", "--no-extensions"];
    const result = run([...flags, "probe", ...args]);
    expect(result.stderr.toString()).toBe("");
    expect(result.exitCode).toBe(0);
    expect(JSON.parse(result.stdout.toString())).toEqual(args);
    const disabled = run(["--no-extensions", ...flags, "probe"]);
    expect(disabled.exitCode).not.toBe(0);
  }
);

test("installed wrapper does not discard unsupported caller flags", () => {
  const result = run(["--extension", "session", "skill", "path"]);
  expect(result.exitCode).toBe(1);
  expect(result.stderr.toString()).toContain("not `skill`");
});

for (const command of ["show", "resume"]) {
  test.each([
    [[], true, true],
    [["--no-extensions"], false, false],
    [["--disable-extension", "hunk-commit-log"], false, true],
    [["--disable-extension=jev-priority"], true, false],
    [["--disable-extension", "hunk-commit-log", "--enable-extension=hunk-commit-log"], true, true],
  ])(
    `installed wrapper loads ${command} with current selection: %j`,
    async (flags, commits, jev) => {
      if (command === "resume") {
        // Legacy markers may contain a master-off setting or old package paths.
        mkdirSync(join(repo, ".git/hunk"), { recursive: true });
        writeFileSync(
          join(repo, ".git/hunk/resume.json"),
          JSON.stringify({
            version: 1,
            updatedAt: new Date().toISOString(),
            input: {
              kind: "show",
              ref: "HEAD",
              options: {
                extensionPaths: ["/old-package/extensions"],
                extensions: false,
                extensionSelectionOverrides: [{ id: "hunk-commit-log", enabled: false }],
              },
            },
          })
        );
      }
      const session = await harness.launchHunk({
        args: [...flags, command, ...(command === "show" ? ["HEAD"] : [])],
        cwd: repo,
        cols: 140,
        rows: 32,
        env,
      });
      try {
        await session.waitForText(/authenticated = true/, { timeout: 15000 });
        if (commits) await session.waitForText(/Commits 2\/2/, { timeout: 15000 });
        if (jev) await session.waitForText(/set TYPESAFE_API_KEY/, { timeout: 15000 });
        const screen = await session.text({ immediate: true });
        expect(screen.includes("Commits 2/2")).toBe(commits);
        expect(screen.includes("set TYPESAFE_API_KEY")).toBe(jev);
        expect(screen).not.toContain("/old-package");
      } finally {
        session.close();
      }
    },
    30000
  );
}
