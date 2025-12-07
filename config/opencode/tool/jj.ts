// Custom jj (jujutsu) tools for non-interactive version control operations
import { tool } from "@opencode-ai/plugin"

// TODO: Add jj_new - create new empty change
// TODO: Add jj_squash - squash changes into parent commit
// TODO: Add jj_describe - set commit message for a revision
// TODO: Add jj_bookmark_set - set bookmark on a revision

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
    const result = await Bun.$`jj split -m ${args.message} ${args.files}`.text()
    return result.trim()
  },
})
