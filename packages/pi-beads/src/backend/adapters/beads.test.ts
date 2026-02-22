/**
 * Tests for the beads (bd) adapter.
 *
 * Internal pure functions are tested indirectly via the public adapter interface.
 * pi.exec is mocked to avoid requiring a real bd installation.
 */

import { describe, test, expect, beforeEach, mock } from "bun:test"

// ---- Module mocks (hoisted before imports) ----
// These let us control isApplicable() without a real filesystem or bd binary.

const fsMock = {
  existsSync: (_path: string): boolean => false,
}

const childProcessMock = {
  spawnSync: (_cmd: string, _args: string[], _opts: unknown): { error: Error | null } => ({
    error: null,
  }),
}

mock.module("node:fs", () => ({
  existsSync: (path: string) => fsMock.existsSync(path),
}))

mock.module("node:child_process", () => ({
  spawnSync: (cmd: string, args: string[], opts: unknown) =>
    childProcessMock.spawnSync(cmd, args, opts),
}))

import beadsAdapter from "./beads.ts"
import type { TaskStatus } from "../../models/task.ts"

// ---- Helpers ----

interface ExecResult {
  code: number
  stdout: string
  stderr: string
}

type ExecHandler = (cmd: string, args: string[]) => ExecResult | Promise<ExecResult>

/** Build a fake pi object whose exec() delegates to the provided handler. */
function makePi(handler: ExecHandler) {
  const calls: { cmd: string; args: string[] }[] = []
  const pi = {
    exec: async (cmd: string, args: string[], _opts?: { timeout?: number }) => {
      calls.push({ cmd, args })
      return handler(cmd, args)
    },
    _calls: calls,
  }
  return pi
}

/** A beads issue fixture for use in mock bd responses. */
function makeIssue(overrides: Partial<{
  id: string
  title: string
  status: string
  priority: number
  issue_type: string
  description: string
  owner: string
  created_at: string
  updated_at: string
}> = {}) {
  return {
    id: "beads-1",
    title: "Test task",
    status: "open",
    priority: 2,
    issue_type: "task",
    description: "A test task",
    owner: "emiller",
    ...overrides,
  }
}

// ---- Status mapping tests ----

describe("fromBackendStatus (via list/show)", () => {
  test("maps bd statuses to internal statuses", async () => {
    const cases: [string, TaskStatus][] = [
      ["open", "open"],
      ["in_progress", "inProgress"],
      ["blocked", "blocked"],
      ["deferred", "deferred"],
      ["closed", "closed"],
    ]

    for (const [bdStatus, expectedInternal] of cases) {
      const issue = makeIssue({ status: bdStatus })
      const pi = makePi(() => ({ code: 0, stdout: JSON.stringify([issue]), stderr: "" }))
      const adapter = beadsAdapter.initialize(pi as any)
      const task = await adapter.show("beads-1")
      expect(task.status, `mapping '${bdStatus}'`).toBe(expectedInternal)
    }
  })

  test("unknown bd status falls back to 'open'", async () => {
    const issue = makeIssue({ status: "future_unknown_status" })
    const pi = makePi(() => ({ code: 0, stdout: JSON.stringify([issue]), stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)
    const task = await adapter.show("beads-1")
    expect(task.status).toBe("open")
  })
})

// ---- list() ----

describe("list()", () => {
  test("fires exactly 3 bd calls: open, in_progress, blocked", async () => {
    const pi = makePi(() => ({ code: 0, stdout: "[]", stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)
    await adapter.list()

    const argSets = pi._calls.map((c) => c.args)
    expect(pi._calls.length).toBe(3)

    const statuses = argSets.map((a) => a[2]) // 0=list, 1=--status, 2=<value>
    expect(statuses).toContain("open")
    expect(statuses).toContain("in_progress")
    expect(statuses).toContain("blocked")

    // All calls must include --json and --limit
    for (const args of argSets) {
      expect(args).toContain("--json")
      expect(args).toContain("--limit")
      expect(args[0]).toBe("list")
    }
  })

  test("returns tasks from all three status queries combined", async () => {
    const openIssue = makeIssue({ id: "beads-1", status: "open" })
    const inProgressIssue = makeIssue({ id: "beads-2", status: "in_progress" })
    const blockedIssue = makeIssue({ id: "beads-3", status: "blocked" })

    const pi = makePi((_cmd, args) => {
      const status = args[2]
      if (status === "open") return { code: 0, stdout: JSON.stringify([openIssue]), stderr: "" }
      if (status === "in_progress") return { code: 0, stdout: JSON.stringify([inProgressIssue]), stderr: "" }
      if (status === "blocked") return { code: 0, stdout: JSON.stringify([blockedIssue]), stderr: "" }
      return { code: 0, stdout: "[]", stderr: "" }
    })

    const adapter = beadsAdapter.initialize(pi as any)
    const tasks = await adapter.list()

    expect(tasks.length).toBe(3)
    const ids = tasks.map((t) => t.ref)
    expect(ids).toContain("beads-1")
    expect(ids).toContain("beads-2")
    expect(ids).toContain("beads-3")
  })

  test("deduplicates tasks that appear in multiple status lists", async () => {
    // Same task ID returned from open AND blocked (shouldn't happen in practice but guard it)
    const asOpen = makeIssue({ id: "beads-99", status: "open", title: "from open" })
    const asBlocked = makeIssue({ id: "beads-99", status: "blocked", title: "from blocked" })

    const pi = makePi((_cmd, args) => {
      const status = args[2]
      if (status === "open") return { code: 0, stdout: JSON.stringify([asOpen]), stderr: "" }
      if (status === "blocked") return { code: 0, stdout: JSON.stringify([asBlocked]), stderr: "" }
      return { code: 0, stdout: "[]", stderr: "" }
    })

    const adapter = beadsAdapter.initialize(pi as any)
    const tasks = await adapter.list()

    // Only one task should survive
    expect(tasks.filter((t) => t.ref === "beads-99").length).toBe(1)
  })

  test("sorts inProgress before open before blocked", async () => {
    const tasks = [
      makeIssue({ id: "b-blocked", status: "blocked", priority: 0 }),
      makeIssue({ id: "b-open", status: "open", priority: 0 }),
      makeIssue({ id: "b-in-progress", status: "in_progress", priority: 0 }),
    ]

    const pi = makePi((_cmd, args) => {
      const status = args[2]
      if (status === "in_progress") return { code: 0, stdout: JSON.stringify([tasks[2]]), stderr: "" }
      if (status === "open") return { code: 0, stdout: JSON.stringify([tasks[1]]), stderr: "" }
      if (status === "blocked") return { code: 0, stdout: JSON.stringify([tasks[0]]), stderr: "" }
      return { code: 0, stdout: "[]", stderr: "" }
    })

    const adapter = beadsAdapter.initialize(pi as any)
    const result = await adapter.list()

    expect(result[0].status).toBe("inProgress")
    expect(result[1].status).toBe("open")
    expect(result[2].status).toBe("blocked")
  })

  test("sorts higher priority (p0) before lower priority (p4) within same status", async () => {
    const issues = [
      makeIssue({ id: "low", status: "open", priority: 4 }),
      makeIssue({ id: "high", status: "open", priority: 0 }),
      makeIssue({ id: "mid", status: "open", priority: 2 }),
    ]

    const pi = makePi((_cmd, args) => {
      const status = args[2]
      if (status === "open") return { code: 0, stdout: JSON.stringify(issues), stderr: "" }
      return { code: 0, stdout: "[]", stderr: "" }
    })

    const adapter = beadsAdapter.initialize(pi as any)
    const result = await adapter.list()

    expect(result[0].ref).toBe("high")
    expect(result[1].ref).toBe("mid")
    expect(result[2].ref).toBe("low")
  })

  test("tasks without priority sort after prioritized tasks", async () => {
    const issues = [
      makeIssue({ id: "nopri", status: "open", priority: undefined as any }),
      makeIssue({ id: "withpri", status: "open", priority: 3 }),
    ]

    const pi = makePi((_cmd, args) => {
      const status = args[2]
      if (status === "open") return { code: 0, stdout: JSON.stringify(issues), stderr: "" }
      return { code: 0, stdout: "[]", stderr: "" }
    })

    const adapter = beadsAdapter.initialize(pi as any)
    const result = await adapter.list()

    expect(result[0].ref).toBe("withpri")
    expect(result[1].ref).toBe("nopri")
  })
})

// ---- show() ----

describe("show()", () => {
  test("calls bd show <ref> --json", async () => {
    const issue = makeIssue({ id: "beads-42" })
    const pi = makePi(() => ({ code: 0, stdout: JSON.stringify([issue]), stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    await adapter.show("beads-42")

    expect(pi._calls.length).toBe(1)
    expect(pi._calls[0].args).toEqual(["show", "beads-42", "--json"])
  })

  test("maps all bd issue fields onto Task", async () => {
    const issue = makeIssue({
      id: "beads-7",
      title: "My task",
      status: "in_progress",
      priority: 1,
      issue_type: "bug",
      description: "Some description",
      owner: "alice",
    })
    const pi = makePi(() => ({ code: 0, stdout: JSON.stringify([issue]), stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)
    const task = await adapter.show("beads-7")

    expect(task.ref).toBe("beads-7")
    expect(task.title).toBe("My task")
    expect(task.status).toBe("inProgress")
    expect(task.priority).toBe("p1")
    expect(task.taskType).toBe("bug")
    expect(task.description).toBe("Some description")
    expect(task.owner).toBe("alice")
  })

  test("throws when bd returns empty array (task not found)", async () => {
    const pi = makePi(() => ({ code: 0, stdout: "[]", stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    const error = await adapter.show("missing-ref").catch((e) => e)
    expect(error).toBeInstanceOf(Error)
    expect((error as Error).message).toContain("Task not found: missing-ref")
  })
})

// ---- create() ----

describe("create()", () => {
  test("sends --title, --priority as integer string, --type, --json", async () => {
    const created = makeIssue({ id: "beads-new", status: "open" })
    const pi = makePi(() => ({ code: 0, stdout: JSON.stringify(created), stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    await adapter.create({ title: "New task", priority: "p2", taskType: "bug" })

    const args = pi._calls[0].args
    expect(args[0]).toBe("create")
    expect(args).toContain("--title")
    expect(args).toContain("New task")
    expect(args).toContain("--priority")
    expect(args[args.indexOf("--priority") + 1]).toBe("2") // integer string, not "p2"
    expect(args).toContain("--type")
    expect(args[args.indexOf("--type") + 1]).toBe("bug")
    expect(args).toContain("--json")
  })

  test("includes --description when provided", async () => {
    const created = makeIssue({ id: "beads-new" })
    const pi = makePi(() => ({ code: 0, stdout: JSON.stringify(created), stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    await adapter.create({ title: "Task with desc", description: "Details here" })

    const args = pi._calls[0].args
    expect(args).toContain("--description")
    expect(args[args.indexOf("--description") + 1]).toBe("Details here")
  })

  test("does NOT include --priority in bd calls without sort flag (regression: bd nil-ptr panic)", async () => {
    // The panic was caused by --sort priority being passed to bd when tasks have null priority.
    // Verify we never send --sort in any create/list call.
    const created = makeIssue({ id: "beads-new" })
    const pi = makePi(() => ({ code: 0, stdout: JSON.stringify(created), stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    await adapter.create({ title: "Task" })

    for (const call of pi._calls) {
      expect(call.args).not.toContain("--sort")
    }
  })

  test("list() calls never pass --sort flag (regression: bd nil-ptr panic)", async () => {
    const pi = makePi(() => ({ code: 0, stdout: "[]", stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)
    await adapter.list()

    for (const call of pi._calls) {
      expect(call.args).not.toContain("--sort")
    }
  })

  test("defaults taskType to 'task' when not provided", async () => {
    const created = makeIssue({ id: "beads-new" })
    const pi = makePi(() => ({ code: 0, stdout: JSON.stringify(created), stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    await adapter.create({ title: "Bare task" })

    const args = pi._calls[0].args
    expect(args[args.indexOf("--type") + 1]).toBe("task")
  })

  test("creates with non-open status by calling update after create", async () => {
    const created = makeIssue({ id: "beads-new", status: "open" })
    let callCount = 0
    const pi = makePi((_cmd, args) => {
      callCount++
      if (args[0] === "create") return { code: 0, stdout: JSON.stringify(created), stderr: "" }
      // update call
      return { code: 0, stdout: "", stderr: "" }
    })
    const adapter = beadsAdapter.initialize(pi as any)

    const task = await adapter.create({ title: "In-flight task", status: "inProgress" })

    // Should have made 2 calls: create + update
    expect(callCount).toBe(2)
    // The update call sets status
    const updateArgs = pi._calls[1].args
    expect(updateArgs[0]).toBe("update")
    expect(updateArgs).toContain("--status")
    expect(updateArgs[updateArgs.indexOf("--status") + 1]).toBe("in_progress")
    expect(task.status).toBe("inProgress")
  })
})

// ---- update() ----

describe("update()", () => {
  test("maps inProgress → in_progress", async () => {
    const pi = makePi(() => ({ code: 0, stdout: "", stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    await adapter.update("beads-5", { status: "inProgress" })

    const args = pi._calls[0].args
    expect(args[0]).toBe("update")
    expect(args[1]).toBe("beads-5")
    expect(args).toContain("--status")
    expect(args[args.indexOf("--status") + 1]).toBe("in_progress")
  })

  test("maps blocked status correctly", async () => {
    const pi = makePi(() => ({ code: 0, stdout: "", stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    await adapter.update("beads-5", { status: "blocked" })

    const args = pi._calls[0].args
    expect(args[args.indexOf("--status") + 1]).toBe("blocked")
  })

  test("maps priority label to integer string", async () => {
    const pi = makePi(() => ({ code: 0, stdout: "", stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    await adapter.update("beads-5", { priority: "p0" })

    const args = pi._calls[0].args
    expect(args).toContain("--priority")
    expect(args[args.indexOf("--priority") + 1]).toBe("0")
  })

  test("maps taskType via --type", async () => {
    const pi = makePi(() => ({ code: 0, stdout: "", stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    await adapter.update("beads-5", { taskType: "feature" })

    const args = pi._calls[0].args
    expect(args).toContain("--type")
    expect(args[args.indexOf("--type") + 1]).toBe("feature")
  })

  test("skips exec when no fields to update", async () => {
    const pi = makePi(() => { throw new Error("should not be called") })
    const adapter = beadsAdapter.initialize(pi as any)

    // Should not throw (no-op)
    await adapter.update("beads-5", {})
    expect(pi._calls.length).toBe(0)
  })
})

// ---- isApplicable() ----

describe("isApplicable()", () => {
  beforeEach(() => {
    // Reset mocks to safe defaults
    fsMock.existsSync = () => false
    childProcessMock.spawnSync = () => ({ error: null })
  })

  test("returns false when .beads/ dir does not exist", () => {
    fsMock.existsSync = () => false
    expect(beadsAdapter.isApplicable()).toBe(false)
  })

  test("returns true when .beads/ exists and bd is in PATH", () => {
    fsMock.existsSync = () => true
    childProcessMock.spawnSync = () => ({ error: null })
    expect(beadsAdapter.isApplicable()).toBe(true)
  })

  test("returns false when .beads/ exists but bd is not in PATH", () => {
    fsMock.existsSync = () => true
    childProcessMock.spawnSync = () => ({ error: new Error("command not found: bd") })
    expect(beadsAdapter.isApplicable()).toBe(false)
  })
})

// ---- Error handling / Go panic regression ----

describe("error handling", () => {
  /**
   * Regression: bd panics with a nil-pointer dereference when tasks have null priority
   * and --sort priority was passed. The stderr panic message must surface as an Error
   * so the user knows what went wrong (not a silent failure or empty error).
   */
  test("bd Go panic on stderr propagates as Error with full message", async () => {
    const panicMsg = [
      "panic: runtime error: invalid memory address or nil pointer dereference",
      "[signal SIGSEGV: segmentation violation code=0x2 addr=0x0 pc=0x106cbc7dc]",
      "",
      "goroutine 1 [running]:",
      "main.sortByPriority(...)",
    ].join("\n")

    const pi = makePi(() => ({ code: 2, stdout: "", stderr: panicMsg }))
    const adapter = beadsAdapter.initialize(pi as any)

    const error = await adapter.list().catch((e) => e)
    expect(error).toBeInstanceOf(Error)
    expect(error.message).toContain("panic")
    expect(error.message).toContain("nil pointer dereference")
  })

  test("bd non-zero exit with stdout fallback surfaces stdout when stderr empty", async () => {
    const pi = makePi(() => ({ code: 1, stdout: "something went wrong", stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    const error = await adapter.list().catch((e) => e)
    expect(error).toBeInstanceOf(Error)
    expect(error.message).toContain("something went wrong")
  })

  test("bd non-zero exit with no output includes command info", async () => {
    const pi = makePi(() => ({ code: 1, stdout: "", stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    const error = await adapter.list().catch((e) => e)
    expect(error).toBeInstanceOf(Error)
    expect(error.message).toContain("failed")
    expect(error.message).toContain("1") // exit code
  })

  test("malformed JSON from bd throws descriptive parse error", async () => {
    const pi = makePi(() => ({ code: 0, stdout: "not valid json {{}", stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    const error = await adapter.list().catch((e) => e)
    expect(error).toBeInstanceOf(Error)
    expect(error.message).toContain("Failed to parse bd output")
  })

  test("non-array JSON from bd list throws descriptive error", async () => {
    const pi = makePi(() => ({ code: 0, stdout: '{"not": "an array"}', stderr: "" }))
    const adapter = beadsAdapter.initialize(pi as any)

    const error = await adapter.list().catch((e) => e)
    expect(error).toBeInstanceOf(Error)
    expect(error.message).toContain("Failed to parse bd output")
  })

  test("panic from in_progress bd call propagates out of list()", async () => {
    // This specifically tests that Promise.all() properly rejects when one of the
    // three parallel bd calls panics — the panic should not be swallowed.
    const panicMsg = "panic: runtime error: invalid memory address or nil pointer dereference"

    const pi = makePi((_cmd, args) => {
      if (args[2] === "in_progress") {
        return { code: 2, stdout: "", stderr: panicMsg }
      }
      return { code: 0, stdout: "[]", stderr: "" }
    })

    const adapter = beadsAdapter.initialize(pi as any)
    const error = await adapter.list().catch((e) => e)
    expect(error).toBeInstanceOf(Error)
    expect(error.message).toContain("panic")
  })
})

// ---- Regression: dolt concurrent access panic ----

describe("dolt concurrency (regression)", () => {
  /**
   * Regression: bd uses dolt as its database backend. Running 3 bd processes
   * in parallel (Promise.all) causes a race in DoltDB.SetCrashOnFatalError,
   * resulting in a SIGSEGV nil-pointer panic. The fix is sequential execution.
   */
  test("list() calls bd sequentially, not in parallel", async () => {
    // Track call order — each call must START after the previous FINISHED.
    // We simulate async delay to catch if calls overlap.
    const timeline: { status: string; event: "start" | "end"; time: number }[] = []
    let callIndex = 0

    const pi = makePi(async (_cmd, args) => {
      const status = args[2]
      const idx = callIndex++
      timeline.push({ status, event: "start", time: idx })
      // Simulate async work (if parallel, starts would bunch before ends)
      await new Promise((r) => setTimeout(r, 5))
      timeline.push({ status, event: "end", time: idx })
      return { code: 0, stdout: "[]", stderr: "" }
    })

    const adapter = beadsAdapter.initialize(pi as any)
    await adapter.list()

    // With sequential execution: start0, end0, start1, end1, start2, end2
    // With parallel execution: start0, start1, start2, end0, end1, end2
    expect(timeline.length).toBe(6)
    for (let i = 0; i < 3; i++) {
      expect(timeline[i * 2].event).toBe("start")
      expect(timeline[i * 2 + 1].event).toBe("end")
      // Each start must follow the previous end
      if (i > 0) {
        expect(timeline[i * 2].time).toBeGreaterThan(timeline[i * 2 - 1].time)
      }
    }
  })
})

// ---- Adapter metadata ----

describe("adapter metadata", () => {
  test("adapter id is 'beads'", () => {
    const pi = makePi(() => { throw new Error("not called") })
    const adapter = beadsAdapter.initialize(pi as any)
    expect(adapter.id).toBe("beads")
  })

  test("statusMap includes all required statuses", () => {
    const pi = makePi(() => { throw new Error("not called") })
    const adapter = beadsAdapter.initialize(pi as any)
    expect(adapter.statusMap.open).toBeTruthy()
    expect(adapter.statusMap.closed).toBeTruthy()
    expect(adapter.statusMap.inProgress).toBeTruthy()
    expect(adapter.statusMap.blocked).toBeTruthy()
    expect(adapter.statusMap.deferred).toBeTruthy()
  })

  test("priorities list is ordered p0..p4", () => {
    const pi = makePi(() => { throw new Error("not called") })
    const adapter = beadsAdapter.initialize(pi as any)
    expect(adapter.priorities).toEqual(["p0", "p1", "p2", "p3", "p4"])
  })

  test("initializer id is 'beads'", () => {
    expect(beadsAdapter.id).toBe("beads")
  })
})
