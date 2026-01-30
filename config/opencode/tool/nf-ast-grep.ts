// nf-ast-grep.ts - Nextflow semantic code search using ast-grep
// Custom tool for OpenCode that provides LLM-invokable code search capabilities
import { tool } from "@opencode-ai/plugin";

const AST_GREP_DIR = `${process.env.HOME}/.local/share/opencode/ast-grep`;

/**
 * Search Nextflow code using ast-grep semantic patterns
 */
export const search = tool({
  description:
    "Search Nextflow code using ast-grep semantic patterns. Use _ instead of $ for meta-variables (e.g., _NAME instead of $NAME, ___ for multiple nodes).",
  args: {
    pattern: tool.schema
      .string()
      .describe(
        "ast-grep pattern to search for. Use _ for meta-variables (e.g., 'process _NAME { ___ }' to find processes)"
      ),
    directory: tool.schema
      .string()
      .optional()
      .describe("Directory to search (defaults to current directory)"),
  },
  async execute(args) {
    const dir = args.directory || process.cwd();
    try {
      const result =
        await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p ${args.pattern} -l nextflow ${dir}`.text();
      return result.trim() || "No matches found";
    } catch (error) {
      return `Error searching: ${error instanceof Error ? error.message : "Unknown error"}`;
    }
  },
});

/**
 * Find all Nextflow process definitions
 */
export const find_processes = tool({
  description:
    "Find all Nextflow process definitions in the codebase. Returns file paths and process names.",
  args: {
    directory: tool.schema
      .string()
      .optional()
      .describe("Directory to search (defaults to current directory)"),
  },
  async execute(args) {
    const dir = args.directory || process.cwd();
    try {
      const result =
        await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p 'process _NAME { ___ }' -l nextflow ${dir}`.text();
      return result.trim() || "No process definitions found";
    } catch (error) {
      return `Error searching: ${error instanceof Error ? error.message : "Unknown error"}`;
    }
  },
});

/**
 * Find all Nextflow workflow definitions
 */
export const find_workflows = tool({
  description:
    "Find all Nextflow workflow definitions (both named workflows and the main entry workflow).",
  args: {
    directory: tool.schema
      .string()
      .optional()
      .describe("Directory to search (defaults to current directory)"),
  },
  async execute(args) {
    const dir = args.directory || process.cwd();
    try {
      const named =
        await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p 'workflow _NAME { ___ }' -l nextflow ${dir}`.text();
      const entry =
        await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p 'workflow { ___ }' -l nextflow ${dir}`.text();

      const results: string[] = [];
      if (named.trim()) results.push(`Named workflows:\n${named.trim()}`);
      if (entry.trim()) results.push(`Entry workflow:\n${entry.trim()}`);

      return results.join("\n\n") || "No workflow definitions found";
    } catch (error) {
      return `Error searching: ${error instanceof Error ? error.message : "Unknown error"}`;
    }
  },
});

/**
 * Find Nextflow channel factory operations
 */
export const find_channels = tool({
  description:
    "Find Nextflow channel factory operations (Channel.of, Channel.fromPath, Channel.fromFilePairs, Channel.value, Channel.empty).",
  args: {
    directory: tool.schema
      .string()
      .optional()
      .describe("Directory to search (defaults to current directory)"),
  },
  async execute(args) {
    const dir = args.directory || process.cwd();
    const patterns = [
      "Channel.of(___)",
      "Channel.fromPath(___)",
      "Channel.fromFilePairs(___)",
      "Channel.value(___)",
      "Channel.empty()",
    ];

    const results: string[] = [];

    for (const pattern of patterns) {
      try {
        const result =
          await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p ${pattern} -l nextflow ${dir}`.text();
        if (result.trim()) {
          results.push(`${pattern}:\n${result.trim()}`);
        }
      } catch {
        // Pattern didn't match, continue
      }
    }

    return results.join("\n\n") || "No channel operations found";
  },
});

/**
 * Find deprecated Nextflow patterns
 */
export const find_deprecated = tool({
  description:
    "Find deprecated Nextflow patterns including Channel.from() (use Channel.of()), .set{} operator, and .into{} operator.",
  args: {
    directory: tool.schema
      .string()
      .optional()
      .describe("Directory to search (defaults to current directory)"),
  },
  async execute(args) {
    const dir = args.directory || process.cwd();
    const patterns = [
      {
        pattern: "Channel.from(___)",
        name: "Channel.from() - deprecated, use Channel.of() or Channel.fromList()",
      },
      {
        pattern: ".set { ___ }",
        name: ".set{} operator - deprecated, use direct variable assignment",
      },
      {
        pattern: ".into { ___ }",
        name: ".into{} operator - deprecated, use direct variable assignment",
      },
    ];

    const results: string[] = [];

    for (const { pattern, name } of patterns) {
      try {
        const result =
          await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p ${pattern} -l nextflow ${dir}`.text();
        if (result.trim()) {
          results.push(`${name}:\n${result.trim()}`);
        }
      } catch {
        // Pattern didn't match, continue
      }
    }

    return results.length > 0
      ? results.join("\n\n")
      : "No deprecated patterns found - code looks good!";
  },
});

/**
 * Run ast-grep lint rules on Nextflow code
 */
export const lint = tool({
  description:
    "Run ast-grep lint rules on Nextflow code to detect common issues like deprecated patterns, hardcoded paths, and style issues.",
  args: {
    directory: tool.schema
      .string()
      .optional()
      .describe("Directory to lint (defaults to current directory)"),
  },
  async execute(args) {
    const dir = args.directory || process.cwd();
    try {
      const result = await Bun.$`cd ${AST_GREP_DIR} && ast-grep scan ${dir}`.text();
      return result.trim() || "No lint issues found";
    } catch (error) {
      return `Error linting: ${error instanceof Error ? error.message : "Unknown error"}`;
    }
  },
});
