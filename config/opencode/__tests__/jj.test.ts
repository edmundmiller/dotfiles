// Unit tests for jj OpenCode tools
// Tests command construction, error handling, and output formatting
// Purpose: Help agents understand and improve the tools
//
// NOTE: These tests verify command construction by testing the tool logic directly.
// Since Bun.$ is readonly, we test by extracting and verifying command arrays.

import { test, expect, describe } from "bun:test"
import { mockResponses, withWhitespace } from "./__fixtures__/jj-responses"

// ============================================================================
// HELPER: Build command arrays matching tool logic
// These mirror the execute() functions to verify correct command construction
// ============================================================================

const buildSplitCmd = (args: { message: string; files: string[] }) => {
  return ["jj", "split", "-m", args.message, ...args.files]
}

const buildNewCmd = (args: { message?: string; revision?: string; noEdit?: boolean }) => {
  const cmd = ["jj", "new"]
  if (args.message) cmd.push("-m", args.message)
  if (args.revision) cmd.push(args.revision)
  if (args.noEdit) cmd.push("--no-edit")
  return cmd
}

const buildSquashCmd = (args: { message?: string; revision?: string; files?: string[] }) => {
  const cmd = ["jj", "squash"]
  if (args.revision) cmd.push("-r", args.revision)
  if (args.message) cmd.push("-m", args.message)
  if (args.files) cmd.push(...args.files)
  return cmd
}

const buildDescribeCmd = (args: { message: string; revisions?: string[] }) => {
  const cmd = ["jj", "describe", "-m", args.message]
  if (args.revisions) cmd.push(...args.revisions)
  return cmd
}

const buildBookmarkSetCmd = (args: { name: string; revision?: string; allowBackwards?: boolean }) => {
  const cmd = ["jj", "bookmark", "set", args.name]
  if (args.revision) cmd.push("-r", args.revision)
  if (args.allowBackwards) cmd.push("-B")
  return cmd
}

const buildStatusCmd = (args: { paths?: string[] }) => {
  const cmd = ["jj", "status"]
  if (args.paths) cmd.push(...args.paths)
  return cmd
}

const buildLogCmd = (args: {
  revisions?: string
  limit?: number
  patch?: boolean
  summary?: boolean
  noGraph?: boolean
}) => {
  const cmd = ["jj", "log"]
  if (args.revisions) cmd.push("-r", args.revisions)
  if (args.limit) cmd.push("-n", String(args.limit))
  if (args.patch) cmd.push("-p")
  if (args.summary) cmd.push("-s")
  if (args.noGraph) cmd.push("--no-graph")
  return cmd
}

const buildEditCmd = (args: { revision: string }) => {
  return ["jj", "edit", args.revision]
}

// ============================================================================
// SPLIT TOOL TESTS
// ============================================================================

describe("split", () => {
  test("constructs command with message and files", () => {
    const cmd = buildSplitCmd({
      message: "feat: extracted changes",
      files: ["file1.ts", "file2.ts"],
    })

    expect(cmd).toContain("jj")
    expect(cmd).toContain("split")
    expect(cmd).toContain("-m")
    expect(cmd).toContain("feat: extracted changes")
    expect(cmd).toContain("file1.ts")
    expect(cmd).toContain("file2.ts")
  })

  test("handles single file", () => {
    const cmd = buildSplitCmd({ message: "refactor", files: ["single.ts"] })

    expect(cmd).toContain("single.ts")
    expect(cmd.filter((c) => c.endsWith(".ts")).length).toBe(1)
  })

  test("command order: jj split -m <message> <files>", () => {
    const cmd = buildSplitCmd({ message: "test", files: ["a.ts", "b.ts"] })

    expect(cmd).toEqual(["jj", "split", "-m", "test", "a.ts", "b.ts"])
  })

  test("output trimming behavior", () => {
    const output = withWhitespace(mockResponses.split.success)
    const trimmed = output.trim()

    expect(trimmed).not.toStartWith("\n")
    expect(trimmed).not.toStartWith(" ")
    expect(trimmed).not.toEndWith("\n")
    expect(trimmed).not.toEndWith(" ")
  })

  test("preserves multi-line output content", () => {
    const output = mockResponses.split.success.trim()

    expect(output).toContain("Rebased")
    expect(output).toContain("First part")
    expect(output).toContain("Second part")
  })
})

// ============================================================================
// JJ_NEW TOOL TESTS
// ============================================================================

describe("jj_new", () => {
  test("creates new change with no options (minimal command)", () => {
    const cmd = buildNewCmd({})

    expect(cmd).toEqual(["jj", "new"])
  })

  test("includes message when provided", () => {
    const cmd = buildNewCmd({ message: "WIP: new feature" })

    expect(cmd).toContain("-m")
    expect(cmd).toContain("WIP: new feature")
  })

  test("includes revision parent when provided", () => {
    const cmd = buildNewCmd({ revision: "main" })

    expect(cmd).toContain("main")
  })

  test("includes --no-edit flag when noEdit is true", () => {
    const cmd = buildNewCmd({ noEdit: true })

    expect(cmd).toContain("--no-edit")
  })

  test("omits --no-edit flag when noEdit is false", () => {
    const cmd = buildNewCmd({ noEdit: false })

    expect(cmd).not.toContain("--no-edit")
  })

  test("omits --no-edit flag when noEdit is undefined", () => {
    const cmd = buildNewCmd({})

    expect(cmd).not.toContain("--no-edit")
  })

  test("combines all options correctly", () => {
    const cmd = buildNewCmd({
      message: "feat: complete",
      revision: "@-",
      noEdit: true,
    })

    expect(cmd).toContain("jj")
    expect(cmd).toContain("new")
    expect(cmd).toContain("-m")
    expect(cmd).toContain("feat: complete")
    expect(cmd).toContain("@-")
    expect(cmd).toContain("--no-edit")
  })

  test("command order: jj new [-m msg] [revision] [--no-edit]", () => {
    const cmd = buildNewCmd({
      message: "msg",
      revision: "rev",
      noEdit: true,
    })

    // Verify order: message before revision before flag
    const mIdx = cmd.indexOf("-m")
    const revIdx = cmd.indexOf("rev")
    const noEditIdx = cmd.indexOf("--no-edit")

    expect(mIdx).toBeLessThan(revIdx)
    expect(revIdx).toBeLessThan(noEditIdx)
  })
})

// ============================================================================
// SQUASH TOOL TESTS
// ============================================================================

describe("squash", () => {
  test("default squash with no args", () => {
    const cmd = buildSquashCmd({})

    expect(cmd).toEqual(["jj", "squash"])
  })

  test("squash with message to avoid editor", () => {
    const cmd = buildSquashCmd({ message: "combined: feature complete" })

    expect(cmd).toContain("-m")
    expect(cmd).toContain("combined: feature complete")
  })

  test("squash specific revision with -r flag", () => {
    const cmd = buildSquashCmd({ revision: "abc123" })

    expect(cmd).toContain("-r")
    expect(cmd).toContain("abc123")
  })

  test("squash only specified files", () => {
    const cmd = buildSquashCmd({ files: ["src/main.ts", "src/utils.ts"] })

    expect(cmd).toContain("src/main.ts")
    expect(cmd).toContain("src/utils.ts")
  })

  test("handles empty files array (no file args added)", () => {
    const cmd = buildSquashCmd({ files: [] })

    expect(cmd).toEqual(["jj", "squash"])
  })

  test("handles undefined files (no file args added)", () => {
    const cmd = buildSquashCmd({})

    expect(cmd).toEqual(["jj", "squash"])
  })

  test("combines revision, message, and files", () => {
    const cmd = buildSquashCmd({
      revision: "qpvuntsm",
      message: "feat: squashed",
      files: ["file.ts"],
    })

    expect(cmd).toContain("-r")
    expect(cmd).toContain("qpvuntsm")
    expect(cmd).toContain("-m")
    expect(cmd).toContain("feat: squashed")
    expect(cmd).toContain("file.ts")
  })

  test("command order: jj squash [-r rev] [-m msg] [files]", () => {
    const cmd = buildSquashCmd({
      revision: "rev",
      message: "msg",
      files: ["file.ts"],
    })

    // -r before -m before files
    const rIdx = cmd.indexOf("-r")
    const mIdx = cmd.indexOf("-m")
    const fileIdx = cmd.indexOf("file.ts")

    expect(rIdx).toBeLessThan(mIdx)
    expect(mIdx).toBeLessThan(fileIdx)
  })
})

// ============================================================================
// DESCRIBE TOOL TESTS
// ============================================================================

describe("describe", () => {
  test("sets message on current revision (@)", () => {
    const cmd = buildDescribeCmd({ message: "feat: new description" })

    expect(cmd).toContain("jj")
    expect(cmd).toContain("describe")
    expect(cmd).toContain("-m")
    expect(cmd).toContain("feat: new description")
  })

  test("updates multiple revisions with same message", () => {
    const cmd = buildDescribeCmd({
      message: "chore: batch update",
      revisions: ["abc123", "def456"],
    })

    expect(cmd).toContain("-m")
    expect(cmd).toContain("chore: batch update")
    expect(cmd).toContain("abc123")
    expect(cmd).toContain("def456")
  })

  test("handles message with special characters", () => {
    const cmd = buildDescribeCmd({ message: 'fix: handle "quotes" and $pecial chars' })

    expect(cmd).toContain('fix: handle "quotes" and $pecial chars')
  })

  test("omits revisions when not provided", () => {
    const cmd = buildDescribeCmd({ message: "simple message" })

    expect(cmd).toEqual(["jj", "describe", "-m", "simple message"])
  })

  test("command order: jj describe -m <message> [revisions...]", () => {
    const cmd = buildDescribeCmd({
      message: "msg",
      revisions: ["rev1", "rev2"],
    })

    expect(cmd).toEqual(["jj", "describe", "-m", "msg", "rev1", "rev2"])
  })
})

// ============================================================================
// BOOKMARK_SET TOOL TESTS
// ============================================================================

describe("bookmark_set", () => {
  test("sets bookmark on current revision", () => {
    const cmd = buildBookmarkSetCmd({ name: "feature-branch" })

    expect(cmd).toContain("jj")
    expect(cmd).toContain("bookmark")
    expect(cmd).toContain("set")
    expect(cmd).toContain("feature-branch")
  })

  test("sets bookmark on specific revision with -r", () => {
    const cmd = buildBookmarkSetCmd({ name: "main", revision: "qpvuntsm" })

    expect(cmd).toContain("-r")
    expect(cmd).toContain("qpvuntsm")
  })

  test("allows backwards movement with -B flag", () => {
    const cmd = buildBookmarkSetCmd({ name: "main", allowBackwards: true })

    expect(cmd).toContain("-B")
  })

  test("omits -B flag when allowBackwards is false", () => {
    const cmd = buildBookmarkSetCmd({ name: "test", allowBackwards: false })

    expect(cmd).not.toContain("-B")
  })

  test("omits -B flag when allowBackwards is undefined", () => {
    const cmd = buildBookmarkSetCmd({ name: "test" })

    expect(cmd).not.toContain("-B")
  })

  test("command order: jj bookmark set <name> [-r rev] [-B]", () => {
    const cmd = buildBookmarkSetCmd({
      name: "mybranch",
      revision: "rev",
      allowBackwards: true,
    })

    expect(cmd).toEqual(["jj", "bookmark", "set", "mybranch", "-r", "rev", "-B"])
  })
})

// ============================================================================
// STATUS TOOL TESTS
// ============================================================================

describe("status", () => {
  test("shows full status with no args", () => {
    const cmd = buildStatusCmd({})

    expect(cmd).toEqual(["jj", "status"])
  })

  test("restricts to specific paths", () => {
    const cmd = buildStatusCmd({ paths: ["src/", "config/"] })

    expect(cmd).toContain("src/")
    expect(cmd).toContain("config/")
  })

  test("handles empty paths array", () => {
    const cmd = buildStatusCmd({ paths: [] })

    expect(cmd).toEqual(["jj", "status"])
  })

  test("handles undefined paths", () => {
    const cmd = buildStatusCmd({})

    expect(cmd).toEqual(["jj", "status"])
  })

  test("output formatting (trims whitespace)", () => {
    const output = withWhitespace(mockResponses.status.withChanges)
    const trimmed = output.trim()

    expect(trimmed).toStartWith("Working copy")
    expect(trimmed).not.toEndWith("\n")
  })
})

// ============================================================================
// LOG TOOL TESTS
// ============================================================================

describe("log", () => {
  test("shows default log with no args", () => {
    const cmd = buildLogCmd({})

    expect(cmd).toEqual(["jj", "log"])
  })

  test("filters by revisions with -r", () => {
    const cmd = buildLogCmd({ revisions: "main..@" })

    expect(cmd).toContain("-r")
    expect(cmd).toContain("main..@")
  })

  test("limits output with -n (converts number to string)", () => {
    const cmd = buildLogCmd({ limit: 5 })

    expect(cmd).toContain("-n")
    expect(cmd).toContain("5")
    expect(cmd).not.toContain(5) // Should be string, not number
  })

  test("shows patch with -p flag", () => {
    const cmd = buildLogCmd({ patch: true })

    expect(cmd).toContain("-p")
  })

  test("omits -p flag when patch is false", () => {
    const cmd = buildLogCmd({ patch: false })

    expect(cmd).not.toContain("-p")
  })

  test("shows summary with -s flag", () => {
    const cmd = buildLogCmd({ summary: true })

    expect(cmd).toContain("-s")
  })

  test("disables graph with --no-graph flag", () => {
    const cmd = buildLogCmd({ noGraph: true })

    expect(cmd).toContain("--no-graph")
  })

  test("combines multiple options", () => {
    const cmd = buildLogCmd({
      revisions: "::",
      limit: 10,
      patch: true,
      summary: true,
      noGraph: true,
    })

    expect(cmd).toContain("-r")
    expect(cmd).toContain("::")
    expect(cmd).toContain("-n")
    expect(cmd).toContain("10")
    expect(cmd).toContain("-p")
    expect(cmd).toContain("-s")
    expect(cmd).toContain("--no-graph")
  })

  test("command order: jj log [-r rev] [-n limit] [-p] [-s] [--no-graph]", () => {
    const cmd = buildLogCmd({
      revisions: "rev",
      limit: 5,
      patch: true,
      summary: true,
      noGraph: true,
    })

    expect(cmd).toEqual(["jj", "log", "-r", "rev", "-n", "5", "-p", "-s", "--no-graph"])
  })
})

// ============================================================================
// EDIT TOOL TESTS
// ============================================================================

describe("edit", () => {
  test("edits specified revision", () => {
    const cmd = buildEditCmd({ revision: "rlvkpnzs" })

    expect(cmd).toContain("jj")
    expect(cmd).toContain("edit")
    expect(cmd).toContain("rlvkpnzs")
  })

  test("accepts revision alias @-", () => {
    const cmd = buildEditCmd({ revision: "@-" })

    expect(cmd).toContain("@-")
  })

  test("accepts bookmark name as revision", () => {
    const cmd = buildEditCmd({ revision: "main" })

    expect(cmd).toContain("main")
  })

  test("command format: jj edit <revision>", () => {
    const cmd = buildEditCmd({ revision: "abc123" })

    expect(cmd).toEqual(["jj", "edit", "abc123"])
  })

  test("output trimming behavior", () => {
    const output = withWhitespace(mockResponses.edit.success)
    const trimmed = output.trim()

    expect(trimmed).toStartWith("Working copy")
    expect(trimmed).not.toEndWith("\n")
  })
})

// ============================================================================
// OUTPUT FORMATTING TESTS (Cross-cutting)
// ============================================================================

describe("output formatting", () => {
  test("trim removes leading whitespace", () => {
    const output = "   \n\n  content"
    expect(output.trim()).toBe("content")
  })

  test("trim removes trailing whitespace", () => {
    const output = "content  \n\n   "
    expect(output.trim()).toBe("content")
  })

  test("trim handles whitespace-only input", () => {
    const output = "   \n\n   "
    expect(output.trim()).toBe("")
  })

  test("trim preserves internal newlines", () => {
    const output = "line1\nline2\nline3"
    expect(output.trim()).toBe("line1\nline2\nline3")
  })

  test("all mock responses are properly formatted", () => {
    // Verify fixtures don't have issues
    const responses = [
      mockResponses.status.withChanges,
      mockResponses.log.default,
      mockResponses.jj_new.success,
      mockResponses.squash.success,
      mockResponses.describe.success,
      mockResponses.bookmark_set.success,
      mockResponses.edit.success,
    ]

    for (const response of responses) {
      const trimmed = response.trim()
      expect(trimmed.length).toBeGreaterThan(0)
      expect(trimmed).not.toMatch(/^\s/)
      expect(trimmed).not.toMatch(/\s$/)
    }
  })
})

// ============================================================================
// ERROR HANDLING TESTS
// ============================================================================

describe("error handling", () => {
  test("error responses are available for testing", () => {
    expect(mockResponses.errors.notInRepo).toContain("Error")
    expect(mockResponses.errors.revisionNotFound).toContain("Error")
    expect(mockResponses.errors.immutableCommit).toContain("Error")
  })

  test("error messages contain helpful context", () => {
    expect(mockResponses.errors.notInRepo).toContain("jj repo")
    expect(mockResponses.errors.revisionNotFound).toContain("doesn't exist")
    expect(mockResponses.errors.immutableCommit).toContain("immutable")
  })
})
