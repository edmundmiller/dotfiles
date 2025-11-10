#!/usr/bin/env bun

/**
 * AI-powered commit message generator for jujutsu
 * Uses Claude CLI to generate conventional commit messages
 */

import { createSpinner } from "nanospinner";
import { existsSync } from "fs";
import { homedir } from "os";
import { join } from "path";
import { parseArgs, stripMarkdownFences, type Args } from "./jj-ai-desc-testable";

const showHelp = () => {
  console.log(`
AI-powered commit message generator for jujutsu

USAGE:
    jj-ai-desc [OPTIONS]

OPTIONS:
    -r, --revision <REV>    Revision to describe (default: @)
    -e, --edit              Open editor after generating message
    -h, --help              Show this help message

EXAMPLES:
    jj-ai-desc              # Generate message for current commit
    jj-ai-desc -e           # Generate and open editor
    jj-ai-desc -r @-        # Generate for parent commit
`);
};

const runCommand = async (
  cmd: string[],
  options: { stdin?: string } = {}
): Promise<{ stdout: string; stderr: string; exitCode: number }> => {
  const proc = Bun.spawn(cmd, {
    stdin: options.stdin ? "pipe" : undefined,
    stdout: "pipe",
    stderr: "pipe",
  });

  if (options.stdin && proc.stdin) {
    // Bun's stdin is a FileSink, use write() directly
    proc.stdin.write(options.stdin);
    proc.stdin.end();
  }

  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);

  const exitCode = await proc.exited;

  return { stdout, stderr, exitCode };
};

const main = async () => {
  const args = parseArgs(process.argv.slice(2));

  if (args.help) {
    showHelp();
    process.exit(0);
  }

  // Step 1: Get the diff
  const spinner = createSpinner("Getting diff...").start();

  const { stdout: diffText, stderr: diffError, exitCode: diffExitCode } =
    await runCommand(["jj", "diff", "-r", args.revision]);

  if (diffExitCode !== 0) {
    spinner.error({ text: "Failed to get diff" });
    console.error(`\x1b[31mError:\x1b[0m ${diffError}`);
    process.exit(1);
  }

  if (!diffText.trim()) {
    spinner.warn({ text: "No changes to describe" });
    process.exit(0);
  }

  spinner.success({ text: "Got diff" });

  // Step 2: Get recent commit history for context
  spinner.start({ text: "Getting commit context..." });

  const { stdout: logText, exitCode: logExitCode } = await runCommand([
    "jj",
    "log",
    "--no-graph",
    "-r",
    "ancestors(@-)",
    "--limit",
    "5",
    "-T",
    'commit_id.short() ++ "\\t" ++ description.first_line() ++ "\\n"',
  ]);

  let commitContext = "";
  if (logExitCode === 0 && logText.trim()) {
    // Parse the log output and format as JSON for TOON conversion
    const commits = logText
      .trim()
      .split("\n")
      .filter((line) => line.trim())
      .map((line) => {
        const [id, ...messageParts] = line.split("\t");
        return {
          id: id.trim(),
          message: messageParts.join("\t").trim(),
        };
      });

    if (commits.length > 0) {
      const recentCommits = { recent_commits: commits };
      commitContext = `Recent commit history for context:\n\`\`\`json\n${JSON.stringify(recentCommits, null, 2)}\n\`\`\`\n\n`;
      spinner.success({ text: `Got ${commits.length} recent commits` });
    } else {
      spinner.warn({ text: "No recent commits found" });
    }
  } else {
    spinner.warn({ text: "Could not get commit history" });
  }

  // Step 3: Generate commit message
  spinner.start({ text: "Generating commit message..." });

  const claudePath = join(homedir(), ".local", "bin", "claude");

  if (!existsSync(claudePath)) {
    spinner.error({
      text: `Claude CLI not found at ${claudePath}`,
    });
    console.error(
      "\nInstall it with: curl -fsSL https://raw.githubusercontent.com/anthropics/claude-code/main/install.sh | sh"
    );
    process.exit(1);
  }

  try {
    // Combine commit context and diff for Claude
    const claudeInput = commitContext + `Here is the diff to describe:\n\n${diffText}`;

    const { stdout: claudeOutput, stderr: claudeError, exitCode: claudeExitCode } =
      await runCommand(
        [
          claudePath,
          "-p",
          "Generate ONLY a conventional commit message (feat/fix/refactor/docs/test/chore/style/perf) for this diff. Consider the style and context of recent commits. Output the message and nothing else. Keep it under 72 chars.",
          "--model",
          "haiku",
          "--output-format",
          "text",
          "--tools",
          "",
        ],
        { stdin: claudeInput }
      );

    if (claudeExitCode !== 0) {
      spinner.error({ text: "Failed to generate commit message" });
      console.error(`\x1b[31mError:\x1b[0m ${claudeError}`);
      process.exit(1);
    }

    const commitMessage = stripMarkdownFences(claudeOutput);

    if (!commitMessage) {
      spinner.error({ text: "Claude returned an empty commit message" });
      process.exit(1);
    }

    spinner.success({ text: `Generated: ${commitMessage}` });

    // Step 3: Apply the commit message
    spinner.start({ text: "Applying commit message..." });

    const jjCmd = ["jj", "describe", "-r", args.revision];
    if (args.edit) {
      jjCmd.push("--edit");
    }

    const { stderr: jjError, exitCode: jjExitCode } = await runCommand(
      [...jjCmd, "--stdin"],
      { stdin: commitMessage }
    );

    if (jjExitCode !== 0) {
      spinner.error({ text: "Failed to apply commit message" });
      console.error(`\x1b[31mError:\x1b[0m ${jjError}`);
      process.exit(1);
    }

    spinner.success({ text: "Commit message applied" });
  } catch (error) {
    spinner.error({ text: `Error: ${error}` });
    process.exit(1);
  }
};

main().catch((error) => {
  console.error(`\x1b[31mUnexpected error:\x1b[0m ${error}`);
  process.exit(1);
});
