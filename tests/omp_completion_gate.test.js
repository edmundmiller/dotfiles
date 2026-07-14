import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtemp, mkdir, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

const EXTENSION = path.resolve(".omp/extensions/completion-gate.js");
const temporaries = [];

function run(command, args, options = {}) {
  const result = Bun.spawnSync([command, ...args], {
    cwd: options.cwd,
    env: { ...process.env, ...options.env },
    stdout: "pipe",
    stderr: "pipe",
  });
  return {
    code: result.exitCode,
    killed: result.signalCode != null,
    stdout: result.stdout.toString(),
    stderr: result.stderr.toString(),
  };
}

async function repository(target = true) {
  const root = await mkdtemp(path.join(tmpdir(), "omp-completion-gate-"));
  temporaries.push(root);
  run("git", ["init", "-q"], { cwd: root });
  run("git", ["config", "user.email", "test@example.com"], { cwd: root });
  run("git", ["config", "user.name", "Test"], { cwd: root });
  await writeFile(path.join(root, "tracked.txt"), "initial\n");
  if (target) {
    await mkdir(path.join(root, ".codex"));
    await mkdir(path.join(root, "scripts"));
    await writeFile(path.join(root, ".codex/hooks.json"), "{}\n");
    await writeFile(path.join(root, "scripts/codex-validate-stop"), "#!/bin/sh\n");
  }
  run("git", ["add", "."], { cwd: root });
  run("git", ["commit", "-qm", "initial"], { cwd: root });
  return root;
}

async function harness(
  cwd,
  checker = async () => ({ code: 0, killed: false, stdout: "", stderr: "" })
) {
  const handlers = new Map();
  let tool;
  let activeTools = ["read"];
  const pi = {
    zod: { object: (shape) => ({ shape }) },
    on(name, handler) {
      handlers.set(name, handler);
    },
    registerTool(value) {
      tool = value;
    },
    getActiveTools() {
      return activeTools;
    },
    setActiveTools(value) {
      activeTools = value;
    },
    async exec(command, args, options = {}) {
      if (command === "bash" && args[0] === "scripts/completion-check") return checker(options);
      return run(command, args, options);
    },
  };
  const module = await import(`${EXTENSION}?test=${crypto.randomUUID()}`);
  module.default(pi);
  await handlers.get("session_start")?.({}, { cwd });
  return {
    activeTools: () => activeTools,
    handler: (name) => handlers.get(name),
    tool: () => tool,
    check: (signal = new AbortController().signal) =>
      tool.execute("id", {}, signal, undefined, { cwd }),
    stop: () => handlers.get("session_stop")?.({}, { cwd }),
  };
}

function text(result) {
  return result.content.map((entry) => entry.text).join("\n");
}

beforeEach(() => {
  temporaries.length = 0;
});

afterEach(async () => {
  await Promise.all(
    temporaries.map((directory) => rm(directory, { recursive: true, force: true }))
  );
});

describe("OMP completion gate", () => {
  test("stays inactive outside the target repository", async () => {
    const root = await repository(false);
    const gate = await harness(root);
    expect(gate.activeTools()).toEqual(["read"]);
    expect(await gate.stop()).toBeUndefined();
  });

  test("activates from a nested target directory", async () => {
    const root = await repository();
    const nested = path.join(root, "nested");
    await mkdir(nested);
    const gate = await harness(nested);
    expect(gate.activeTools()).toContain("completion_check");
    expect(gate.tool().defaultInactive).toBe(true);
    expect(gate.tool().approval).toBe("read");
    expect(gate.tool().name).toBe("completion_check");
    expect(gate.tool().label).toBe("Completion Check");
    expect(gate.tool().parameters).toBeDefined();
    expect(gate.tool().description).toBe(
      "Run required dotfiles completion checks after all requested work and final edits are complete. A pass is valid for the next stop attempt only."
    );
  });

  test("continues an unverified stop", async () => {
    const gate = await harness(await repository());
    expect(await gate.stop()).toMatchObject({ continue: true });
  });

  test("continues after a failed check", async () => {
    const gate = await harness(await repository(), async () => ({
      code: 1,
      killed: false,
      stdout: "reason\n",
      stderr: "details\n",
    }));
    const result = await gate.check();
    expect(result.isError).toBe(true);
    expect(text(result)).toContain("details\nreason");
    expect(await gate.stop()).toMatchObject({ continue: true });
  });

  test("allows one unchanged stop after a pass", async () => {
    const gate = await harness(await repository());
    expect((await gate.check()).isError).toBeUndefined();
    expect(await gate.stop()).toBeUndefined();
    expect(await gate.stop()).toMatchObject({ continue: true });
  });

  test("rejects tracked changes after a pass", async () => {
    const root = await repository();
    const gate = await harness(root);
    await gate.check();
    await writeFile(path.join(root, "tracked.txt"), "changed\n");
    expect(await gate.stop()).toMatchObject({ continue: true });
  });

  test("rejects changed content at the same untracked path", async () => {
    const root = await repository();
    const file = path.join(root, "untracked.txt");
    await writeFile(file, "first\n");
    const gate = await harness(root);
    await gate.check();
    await writeFile(file, "second\n");
    expect(await gate.stop()).toMatchObject({ continue: true });
  });

  test("requires a new pass after a stale stop even when reverted", async () => {
    const root = await repository();
    const gate = await harness(root);
    await gate.check();
    await writeFile(path.join(root, "tracked.txt"), "changed\n");
    expect(await gate.stop()).toMatchObject({ continue: true });
    await writeFile(path.join(root, "tracked.txt"), "initial\n");
    expect(await gate.stop()).toMatchObject({ continue: true });
  });

  test("a failed rerun invalidates an earlier pass", async () => {
    const root = await repository();
    let calls = 0;
    const gate = await harness(root, async () =>
      ++calls === 1
        ? { code: 0, killed: false, stdout: "", stderr: "" }
        : { code: 1, killed: false, stdout: "failed\n", stderr: "" }
    );
    await gate.check();
    expect((await gate.check()).isError).toBe(true);
    expect(await gate.stop()).toMatchObject({ continue: true });
  });

  test("snapshot command failure returns continuation", async () => {
    const root = await repository();
    const gate = await harness(root);
    await gate.check();
    await rm(path.join(root, ".git"), { recursive: true });
    const result = await gate.stop();
    expect(result.continue).toBe(true);
    expect(result.additionalContext).toContain("git rev-parse HEAD failed");
  });

  test("stop snapshot timeout fails closed", async () => {
    const gate = await harness(await repository());
    await gate.check();
    const original = AbortSignal.timeout;
    AbortSignal.timeout = () => AbortSignal.abort(new DOMException("Timed out", "TimeoutError"));
    try {
      const result = await gate.stop();
      expect(result.continue).toBe(true);
      expect(result.additionalContext).toContain("timed out");
    } finally {
      AbortSignal.timeout = original;
    }
  });

  test("cancelled snapshot checks fail closed", async () => {
    const gate = await harness(await repository());
    const result = await gate.check(AbortSignal.abort());
    expect(result.isError).toBe(true);
    expect(text(result)).toBe("Completion checks were cancelled or timed out.");
  });

  test("cancelled checks fail closed", async () => {
    const gate = await harness(await repository(), async () => ({
      code: null,
      killed: true,
      stdout: "",
      stderr: "",
    }));
    const result = await gate.check();
    expect(result.isError).toBe(true);
    expect(text(result)).toBe("Completion checks were cancelled or timed out.");
    expect(await gate.stop()).toMatchObject({ continue: true });
  });

  test("rejects a successful checker that modifies the tree", async () => {
    const root = await repository();
    const gate = await harness(root, async () => {
      await writeFile(path.join(root, "tracked.txt"), "mutated\n");
      return { code: 0, killed: false, stdout: "", stderr: "" };
    });
    const result = await gate.check();
    expect(result.isError).toBe(true);
    expect(text(result)).toBe(
      "Working tree changed while completion checks ran; rerun completion_check."
    );
  });

  test("hashes symlink targets without following them", async () => {
    const root = await repository();
    await symlink("tracked.txt", path.join(root, "link"));
    const gate = await harness(root);
    await gate.check();
    await rm(path.join(root, "link"));
    await symlink("missing.txt", path.join(root, "link"));
    expect(await gate.stop()).toMatchObject({ continue: true });
  });
});
