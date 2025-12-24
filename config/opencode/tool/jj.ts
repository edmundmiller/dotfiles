// Custom jj (jujutsu) tools for non-interactive version control operations
import { tool } from "@opencode-ai/plugin"

export const split = tool({
  description:
    "Split the current jj working copy by moving specified files into a new commit. " +
    "Creates a commit with the given message containing only the specified files, " +
    "leaving remaining changes in the working copy. This is non-interactive.",
  args: {
    message: tool.schema.string().describe("Commit message for the split-off changes"),
    files: tool.schema
      .array(tool.schema.string())
      .describe("List of file paths to include in the split commit"),
  },
  async execute(args) {
    // NOTE: Add error handling here
    const result = await Bun.$`jj split -m ${args.message} ${args.files}`.text()
    return result.trim()
  },
})

export const jj_new = tool({
  description:
    "Create new empty change and edit it in working copy. " +
    "By default creates child of @. Use noEdit to create without switching to it.",
  args: {
    message: tool.schema.string().optional().describe("Commit message (optional)"),
    revision: tool.schema.string().optional().describe("Parent revision (default: @)"),
    noEdit: tool.schema.boolean().optional().describe("Don't edit the new change"),
  },
  async execute(args) {
    // NOTE: Add error handling here
    const cmd = ["jj", "new"]
    if (args.message) cmd.push("-m", args.message)
    if (args.revision) cmd.push(args.revision)
    if (args.noEdit) cmd.push("--no-edit")

    const result = await Bun.$`${cmd}`.text()
    return result.trim()
  },
})

export const squash = tool({
  description:
    "Move changes from revision into parent. " +
    "Default squashes @ into parent. Use message to set combined description.",
  args: {
    message: tool.schema.string().optional().describe("Combined description (avoids editor)"),
    revision: tool.schema.string().optional().describe("Source revision (default: @)"),
    files: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe("Only squash these paths"),
  },
  async execute(args) {
    // NOTE: Add error handling here
    const cmd = ["jj", "squash"]
    if (args.revision) cmd.push("-r", args.revision)
    if (args.message) cmd.push("-m", args.message)
    if (args.files) cmd.push(...args.files)

    const result = await Bun.$`${cmd}`.text()
    return result.trim()
  },
})

export const describe = tool({
  description:
    "Update change description non-interactively. " +
    "Default updates @. Can update multiple revisions with same message.",
  args: {
    message: tool.schema.string().describe("The commit message to set"),
    revisions: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe("Revisions to update (default: @)"),
  },
  async execute(args) {
    // NOTE: Add error handling here
    const cmd = ["jj", "describe", "-m", args.message]
    if (args.revisions) cmd.push(...args.revisions)

    const result = await Bun.$`${cmd}`.text()
    return result.trim()
  },
})

export const bookmark_set = tool({
  description:
    "Create or update bookmark to point at revision. " +
    "Default points to @. Use allowBackwards for force moves.",
  args: {
    name: tool.schema.string().describe("Bookmark name to set"),
    revision: tool.schema.string().optional().describe("Target revision (default: @)"),
    allowBackwards: tool.schema
      .boolean()
      .optional()
      .describe("Allow moving bookmark backwards/sideways"),
  },
  async execute(args) {
    // NOTE: Add error handling here
    const cmd = ["jj", "bookmark", "set", args.name]
    if (args.revision) cmd.push("-r", args.revision)
    if (args.allowBackwards) cmd.push("-B")

    const result = await Bun.$`${cmd}`.text()
    return result.trim()
  },
})

export const status = tool({
  description:
    "Show high-level repo status: working copy, parents, changes summary, conflicts, bookmarks.",
  args: {
    paths: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe("Restrict status to these paths"),
  },
  async execute(args) {
    // NOTE: Add error handling here
    const cmd = ["jj", "status"]
    if (args.paths) cmd.push(...args.paths)

    const result = await Bun.$`${cmd}`.text()
    return result.trim()
  },
})

export const log = tool({
  description:
    "Show revision history as graph. Default shows mutable revisions. " +
    "Use revisions arg for custom revset (e.g. '::' for all).",
  args: {
    revisions: tool.schema.string().optional().describe("Revset to show (default: mutable)"),
    limit: tool.schema.number().optional().describe("Max revisions to show"),
    patch: tool.schema.boolean().optional().describe("Show patch/diff"),
    summary: tool.schema.boolean().optional().describe("Show change summary per path"),
    noGraph: tool.schema.boolean().optional().describe("Flat list instead of graph"),
  },
  async execute(args) {
    // NOTE: Add error handling here
    const cmd = ["jj", "log"]
    if (args.revisions) cmd.push("-r", args.revisions)
    if (args.limit) cmd.push("-n", String(args.limit))
    if (args.patch) cmd.push("-p")
    if (args.summary) cmd.push("-s")
    if (args.noGraph) cmd.push("--no-graph")

    const result = await Bun.$`${cmd}`.text()
    return result.trim()
  },
})

export const edit = tool({
  description:
    "Set revision as working copy. Changes automatically rebase. " +
    "Generally prefer jj_new + squash workflow instead.",
  args: {
    revision: tool.schema.string().describe("The revision to edit"),
  },
  async execute(args) {
    // NOTE: Add error handling here
    const cmd = ["jj", "edit", args.revision]

    const result = await Bun.$`${cmd}`.text()
    return result.trim()
  },
})
