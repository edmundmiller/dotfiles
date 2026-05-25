// Pure functions for agentmap prompt injection.

export const MAX_LINES = 1000;

/** Truncate YAML to MAX_LINES, appending a marker if truncated. */
export function truncateYaml(yaml: string, maxLines = MAX_LINES): string {
  const lines = yaml.split("\n");
  if (lines.length <= maxLines) return yaml;
  return lines.slice(0, maxLines).join("\n") + "\n# ... truncated";
}

/** Build final system prompt with agentmap XML injected. */
export function buildSystemPrompt(existing: string, yaml: string): string {
  return (
    existing +
    `

<agentmap>
Tree of the most important files in the repo, showing descriptions and definitions:

${yaml}
</agentmap>

<agentmap-instructions>
When creating new files, add a brief description comment at the top explaining the file's purpose. This makes the file discoverable in the agentmap.

When making significant changes to a file's purpose or responsibilities, update its header comment to reflect the changes.

These descriptions appear in the agentmap XML at the start of every agent session.
</agentmap-instructions>`
  );
}
