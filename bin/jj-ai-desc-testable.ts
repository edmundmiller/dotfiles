/**
 * Testable functions extracted from jj-ai-desc.ts
 * This file contains pure functions that can be tested independently
 */

export interface Args {
  revision: string;
  edit: boolean;
  help: boolean;
}

export const stripMarkdownFences = (text: string): string => {
  return text
    .replace(/^```[\w]*\n?/gm, "") // Remove opening fence with optional language
    .replace(/^```\n?$/gm, "") // Remove closing fence
    .trim();
};

export const parseArgs = (argv: string[]): Args => {
  const result: Args = {
    revision: "@",
    edit: false,
    help: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") {
      result.help = true;
    } else if (arg === "--edit" || arg === "-e") {
      result.edit = true;
    } else if (arg === "--revision" || arg === "-r") {
      result.revision = argv[++i] || "@";
    }
  }

  return result;
};
