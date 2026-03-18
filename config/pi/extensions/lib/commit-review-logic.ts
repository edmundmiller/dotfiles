/**
 * Commit review helpers.
 *
 * Shared pure logic for drafting and sanitizing AI-generated commit messages,
 * picking a blocking editor, and building the child-pi prompt.
 */

const CONVENTIONAL_COMMIT_LINE =
  /^(feat|fix|refactor|docs|test|chore|style|perf)(\([^)]+\))?!?:\s*.+/;

function trimMatchingQuotes(text: string): string {
  const trimmed = text.trim();
  if (trimmed.length < 2) return trimmed;

  const first = trimmed[0];
  const last = trimmed[trimmed.length - 1];
  if ((first === '"' && last === '"') || (first === "'" && last === "'")) {
    return trimmed.slice(1, -1).trim();
  }

  return trimmed;
}

export function stripMarkdownFences(text: string): string {
  return text
    .replace(/^```[\w-]*\n?/gm, "")
    .replace(/^```\n?$/gm, "")
    .trim();
}

export function sanitizeCommitMessage(text: string): string {
  const unfenced = trimMatchingQuotes(stripMarkdownFences(text));
  if (!unfenced) return "";

  const lines = unfenced.split("\n");
  const firstCommitLine = lines.findIndex((line) => CONVENTIONAL_COMMIT_LINE.test(line.trim()));

  if (firstCommitLine === -1) {
    return unfenced.trim();
  }

  return lines.slice(firstCommitLine).join("\n").trim();
}

export function chooseCommitEditor(env: NodeJS.ProcessEnv): string {
  const candidates = [env.PI_COMMIT_EDITOR, env.VISUAL, env.EDITOR];

  for (const candidate of candidates) {
    const trimmed = candidate?.trim();
    if (!trimmed) continue;
    if (trimmed === "true" || trimmed === ":" || trimmed === "cat") continue;
    return trimmed;
  }

  return "nvim";
}

export function truncateForPrompt(text: string, maxChars: number): string {
  if (text.length <= maxChars) return text;
  const suffix = `\n\n[truncated to ${maxChars} chars]`;
  return text.slice(0, Math.max(0, maxChars - suffix.length)).trimEnd() + suffix;
}

export function buildCommitDraftPrompt(input: {
  stagedStat: string;
  stagedDiff: string;
  guidance?: string;
}): string {
  const guidance = input.guidance?.trim();

  return [
    "Draft exactly one conventional commit message for the staged change set below.",
    "",
    "Hard rules:",
    "- output only the commit message text",
    "- keep the subject imperative, lowercase, and without a trailing period",
    "- include a body only when it adds real what/why context",
    "- no markdown fences, bullets, explanations, or surrounding quotes",
    "- do not offer multiple options",
    guidance ? "" : "",
    guidance ? `Extra guidance: ${guidance}` : "",
    "",
    "Staged file stats:",
    input.stagedStat.trim() || "(none)",
    "",
    "Staged diff:",
    input.stagedDiff.trim() || "(none)",
  ]
    .filter((line, index, lines) => {
      if (line !== "") return true;
      const previous = index > 0 ? lines[index - 1] : undefined;
      return previous !== "";
    })
    .join("\n");
}
