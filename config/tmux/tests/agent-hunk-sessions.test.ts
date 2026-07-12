import { afterEach, describe, expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { chmod, mkdir, mkdtemp, realpath, rm, symlink, utimes, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";

const collector = join(import.meta.dir, "..", "agent-hunk-sessions.ts");
const temporary: string[] = [];

afterEach(async () => {
  await Promise.all(temporary.splice(0).map((path) => rm(path, { recursive: true, force: true })));
});

async function temp(): Promise<string> {
  const path = await mkdtemp(join(tmpdir(), "agent-hunk-sessions-"));
  temporary.push(path);
  return path;
}

async function jsonl(path: string, records: unknown[], mtime: Date): Promise<void> {
  await mkdir(join(path, ".."), { recursive: true });
  await writeFile(path, records.map((record) => JSON.stringify(record)).join("\n") + "\n");
  await utimes(path, mtime, mtime);
}

type Row = {
  updated: string;
  title: string;
  worktree: string;
  label: string;
  action: string;
  runtime: string;
  token: string;
  cwd: string;
};

function rows(stdout: string): Row[] {
  return stdout
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const fields = line.split("\t");
      expect(fields).toHaveLength(8);
      const [updated, title, worktree, label, action, runtime, encodedToken, encodedCwd] = fields;
      return {
        updated,
        title,
        worktree,
        label,
        action,
        runtime,
        token: Buffer.from(encodedToken, "base64").toString(),
        cwd: Buffer.from(encodedCwd, "base64").toString(),
      };
    });
}

async function run(args: string[]) {
  return Bun.$`${process.execPath} ${collector} list ${args}`.quiet().nothrow();
}

describe("Pi and OMP JSONL metadata", () => {
  test("uses separate roots, streams valid nonempty sessions, canonicalizes cwd, and sanitizes TSV", async () => {
    const root = await temp();
    const worktree = join(root, "tree");
    const alias = join(root, "tree-link");
    const piRoot = join(root, "pi");
    const ompRoot = join(root, "omp");
    const piSessions = join(piRoot, "sessions");
    const ompSessions = join(ompRoot, "sessions");
    await mkdir(worktree);
    await symlink(worktree, alias);
    const old = new Date("2026-01-01T00:00:00.000Z");
    const recent = new Date("2026-01-02T00:00:00.000Z");
    const piPath = join(piSessions, "nested", "pi.jsonl");
    const ompPath = join(ompSessions, "omp.jsonl");
    await jsonl(
      piPath,
      [
        { type: "session", id: "pi-id", cwd: `${alias}/`, title: "header" },
        { type: "message", content: "SECRET MUST NEVER ENTER OUTPUT" },
        { type: "session_info", name: "newest\tPi\nname\r" },
      ],
      old
    );
    await jsonl(
      ompPath,
      [
        { type: "session", id: "omp-id", cwd: worktree, name: "OMP header" },
        { type: "session_info", title: "OMP title" },
        { type: "message", content: { deeply: "private" } },
      ],
      recent
    );
    await mkdir(piSessions, { recursive: true });
    await writeFile(join(piSessions, "malformed.jsonl"), "not-json\n");
    await jsonl(
      join(piSessions, "missing-header-fields.jsonl"),
      [
        { type: "session", id: "", cwd: worktree },
        { type: "message", content: "hidden" },
      ],
      recent
    );
    await jsonl(
      join(piSessions, "header-only.jsonl"),
      [{ type: "session", id: "empty", cwd: worktree }],
      recent
    );
    await jsonl(
      join(piSessions, "outside.jsonl"),
      [
        { type: "session", id: "outside", cwd: root },
        { type: "message", content: "hidden" },
      ],
      recent
    );

    const result = await run([
      "--worktree",
      `${alias}/`,
      "--pi-agent-dir",
      piRoot,
      "--omp-agent-dir",
      ompRoot,
      "--hermes-db",
      join(root, "missing.db"),
      "--opencode-bin",
      join(root, "missing-opencode"),
    ]);

    expect(result.exitCode).toBe(0);
    const output = rows(result.stdout.toString());
    expect(output.map(({ runtime }) => runtime)).toEqual(["omp", "pi"]);
    expect(output[0]).toMatchObject({
      updated: recent.toISOString(),
      title: "OMP title",
      worktree: "tree",
      label: "OMP",
      action: "resume",
      runtime: "omp",
      token: await realpath(ompPath),
      cwd: await realpath(worktree),
    });
    expect(output[1]).toMatchObject({
      updated: old.toISOString(),
      title: "newest Pi name ",
      worktree: "tree",
      label: "Pi",
      action: "resume",
      runtime: "pi",
      token: await realpath(piPath),
      cwd: await realpath(worktree),
    });
    expect(result.stdout.toString()).not.toContain("SECRET");
  });

  test("uses runtime priority only to break equal activity ties", async () => {
    const root = await temp();
    const worktree = join(root, "tree");
    await mkdir(worktree);
    const same = new Date("2026-02-01T00:00:00.000Z");
    for (const [runtime, directory] of [
      ["pi", join(root, "pi")],
      ["omp", join(root, "omp")],
    ] as const) {
      await jsonl(
        join(directory, "sessions", `${runtime}.jsonl`),
        [
          { type: "session", id: runtime, cwd: worktree },
          { type: "message", content: "private" },
        ],
        same
      );
    }
    const result = await run([
      "--worktree",
      worktree,
      "--pi-agent-dir",
      join(root, "pi"),
      "--omp-agent-dir",
      join(root, "omp"),
      "--hermes-db",
      join(root, "missing.db"),
      "--opencode-bin",
      join(root, "missing"),
    ]);
    expect(rows(result.stdout.toString()).map(({ runtime }) => runtime)).toEqual(["omp", "pi"]);
  });
});

describe("Hermes projection", () => {
  test("lists roots and branches, hides delegates/children, and projects compression chains", async () => {
    const root = await temp();
    const worktree = join(root, "tree");
    await mkdir(worktree);
    const dbPath = join(root, "state.db");
    const db = new Database(dbPath);
    db.exec(`
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY, source TEXT NOT NULL, model_config TEXT, parent_session_id TEXT,
        started_at REAL, ended_at REAL, end_reason TEXT, message_count INTEGER, cwd TEXT,
        title TEXT, archived INTEGER DEFAULT 0
      );
      CREATE TABLE messages (id INTEGER PRIMARY KEY, session_id TEXT, role TEXT, content TEXT, timestamp REAL);
    `);
    const insert = db.prepare(`INSERT INTO sessions
      (id, source, model_config, parent_session_id, started_at, ended_at, end_reason, message_count, cwd, title, archived)
      VALUES (?, 'cli', ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
    insert.run("root", "{}", null, 10, null, null, 1, worktree, "Root", 0);
    insert.run(
      "branch",
      '{"_branched_from":"root"}',
      "root",
      20,
      null,
      null,
      1,
      worktree,
      "Branch",
      0
    );
    insert.run(
      "delegate",
      '{"_delegate_from":"root"}',
      "root",
      30,
      null,
      null,
      1,
      worktree,
      "Delegate",
      0
    );
    insert.run("child", "{}", "root", 40, null, null, 1, worktree, "Child", 0);
    insert.run("compressed", "{}", null, 50, 60, "compression", 1, worktree, "Old compressed", 0);
    insert.run("middle", "{}", "compressed", 61, 70, "compression", 2, null, "Middle", 0);
    insert.run("tip", "{}", "middle", 71, null, null, 3, null, "Compressed tip", 0);
    insert.run("archived", "{}", null, 80, null, null, 1, worktree, "Archived", 1);
    insert.run("noncli", "{}", null, 90, null, null, 1, worktree, "Other", 0);
    insert.run(
      "branched-parent",
      "{}",
      null,
      100,
      101,
      "branched",
      1,
      worktree,
      "Branch parent",
      0
    );
    insert.run(
      "branch-by-parent",
      "{}",
      "branched-parent",
      102,
      null,
      null,
      1,
      worktree,
      "Branch by parent",
      0
    );
    insert.run(
      "pre-branch-child",
      "{}",
      "branched-parent",
      99,
      null,
      null,
      1,
      worktree,
      "Not a branch",
      0
    );
    insert.run("empty", "{}", null, 110, null, null, 0, worktree, "Empty", 0);
    insert.run(
      "empty-compressed",
      "{}",
      null,
      120,
      130,
      "compression",
      0,
      worktree,
      "Empty compressed",
      0
    );
    insert.run("empty-tip", "{}", "empty-compressed", 131, null, null, 0, null, null, 0);
    insert.run("resolved-tip", "{}", "empty-tip", 132, null, null, 1, null, "Resolved tip", 0);
    db.query("UPDATE sessions SET source = 'api' WHERE id = 'noncli'").run();
    for (const [session, timestamp] of [
      ["root", 11],
      ["branch", 21],
      ["delegate", 31],
      ["child", 41],
      ["compressed", 55],
      ["middle", 65],
      ["tip", 75],
      ["archived", 81],
      ["noncli", 91],
      ["branched-parent", 101],
      ["branch-by-parent", 102],
      ["pre-branch-child", 99],
      ["resolved-tip", 132],
    ] as const) {
      db.query(
        "INSERT INTO messages (session_id, role, content, timestamp) VALUES (?, 'user', 'private', ?)"
      ).run(session, timestamp);
    }
    db.close();

    const result = await run([
      "--worktree",
      worktree,
      "--pi-agent-dir",
      join(root, "pi"),
      "--omp-agent-dir",
      join(root, "omp"),
      "--hermes-db",
      dbPath,
      "--opencode-bin",
      join(root, "missing"),
    ]);
    expect(result.exitCode).toBe(0);
    const hermes = rows(result.stdout.toString()).filter(({ runtime }) => runtime === "hermes");
    expect(hermes.map(({ token }) => token)).toEqual([
      "resolved-tip",
      "branch-by-parent",
      "branched-parent",
      "tip",
      "branch",
      "root",
    ]);
    expect(hermes.find(({ token }) => token === "tip")).toMatchObject({
      title: "Compressed tip",
      updated: new Date(75_000).toISOString(),
      cwd: await realpath(worktree),
    });
    expect(hermes[0]).toMatchObject({ title: "Resolved tip", cwd: await realpath(worktree) });
  });
});

describe("OpenCode public API", () => {
  test("paginates envelopes, filters nested cwd and invalid rows, and survives repeated cursors", async () => {
    const root = await temp();
    const worktree = join(root, "tree");
    await mkdir(worktree);
    const mock = join(root, "opencode");
    await writeFile(
      mock,
      `#!/bin/sh
if [ "$1 $2" = "service status" ]; then exit 0; fi
case "$*" in
  *"--param cursor=page2"*) printf '%s\\n' '{"data":[{"id":"oc-2","title":"Second","location":{"directory":"${worktree}"},"time":{"updated":2000},"tokens":{"input":0,"output":2,"reasoning":0,"cache":{"read":0,"write":0}}},{"id":"child","parentID":"oc-2","location":{"directory":"${worktree}"},"time":{"updated":3000},"tokens":{"input":1}}],"cursor":{"next":"page2"}}' ;;
  *) printf '%s\\n' '{"data":[{"id":"oc-1","title":"First","location":{"directory":"${worktree}"},"time":{"updated":1000},"tokens":{"input":1,"output":0,"reasoning":0,"cache":{"read":0,"write":0}}},{"id":"empty","location":{"directory":"${worktree}"},"time":{"updated":4000},"tokens":{"input":0,"output":0,"reasoning":0,"cache":{"read":0,"write":0}}},{"id":"outside","location":{"directory":"${root}"},"time":{"updated":5000},"tokens":{"input":1}},{"id":"archived","archived":true,"location":{"directory":"${worktree}"},"time":{"updated":6000},"tokens":{"input":1}}],"cursor":{"next":"page2"}}' ;;
esac
`
    );
    await chmod(mock, 0o755);

    const result = await run([
      "--worktree",
      worktree,
      "--pi-agent-dir",
      join(root, "pi"),
      "--omp-agent-dir",
      join(root, "omp"),
      "--hermes-db",
      join(root, "missing.db"),
      "--opencode-bin",
      mock,
    ]);
    expect(result.exitCode).toBe(0);
    const openCode = rows(result.stdout.toString()).filter(({ runtime }) => runtime === "opencode");
    expect(openCode.map(({ token }) => token)).toEqual(["oc-2", "oc-1"]);
    expect(openCode[0]).toMatchObject({
      label: "OpenCode",
      title: "Second",
      updated: new Date(2000).toISOString(),
    });
  });

  test("omits only OpenCode when service or API is unavailable", async () => {
    const root = await temp();
    const worktree = join(root, "tree");
    await mkdir(worktree);
    const piRoot = join(root, "pi");
    await jsonl(
      join(piRoot, "sessions", "pi.jsonl"),
      [
        { type: "session", id: "pi", cwd: worktree },
        { type: "message", content: "private" },
      ],
      new Date("2026-03-01T00:00:00.000Z")
    );
    const apiBroken = join(root, "opencode-api-broken");
    const serviceBroken = join(root, "opencode-service-broken");
    await writeFile(apiBroken, '#!/bin/sh\n[ "$1 $2" = "service status" ] && exit 0\nexit 1\n');
    await writeFile(serviceBroken, "#!/bin/sh\nexit 1\n");
    await Promise.all([chmod(apiBroken, 0o755), chmod(serviceBroken, 0o755)]);
    for (const broken of [serviceBroken, apiBroken]) {
      const result = await run([
        "--worktree",
        worktree,
        "--pi-agent-dir",
        piRoot,
        "--omp-agent-dir",
        join(root, "omp"),
        "--hermes-db",
        join(root, "missing.db"),
        "--opencode-bin",
        broken,
      ]);
      expect(rows(result.stdout.toString()).map(({ runtime }) => runtime)).toEqual(["pi"]);
      expect(result.stderr.toString()).toContain("OpenCode");
    }
  });
});
